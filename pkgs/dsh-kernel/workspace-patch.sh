#!/usr/bin/env bash
set -euo pipefail

phase=${1:-}
shift || true

die() {
  printf 'dsh-kernel: %s\n' "$1" >&2
  exit 1
}

require_workspace() {
  local path

  for path in \
    apps/cli/package.json \
    pnpm-lock.yaml \
    vendor/group/package.json
  do
    [ -f "$path" ] || die "workspace patch expected file '$path'"
  done

  [ -d packages/bundle ] || die "workspace patch expected directory 'packages/bundle'"
}

patch_workspace_dependencies() {
  local workspace_deps workspace_lock_deps

  require_workspace
  workspace_deps="$TMPDIR/dsh-workspace-dependencies.json"
  workspace_lock_deps="$TMPDIR/dsh-workspace-lock-dependencies.json"

  yq ea -o=json -I=0 \
    '(select(.name | test("^@deepseek-ai/")) | {
      (.name): "workspace:^"
    }) as $item ireduce ({}; . * $item)' \
    vendor/group/package.json packages/*/*/package.json > "$workspace_deps"
  yq ea -o=json -I=0 \
    '(select(.name | test("^@deepseek-ai/")) | {
      (.name): {
        "specifier": "workspace:^",
        "version": "link:" + (filename | sub("/package.json$"; "") | sub("^"; "../../"))
      }
    }) as $item ireduce ({}; . * $item)' \
    vendor/group/package.json packages/*/*/package.json > "$workspace_lock_deps"
  DEPS_FILE="$workspace_deps" yq -i \
    '.dependencies *= load(strenv(DEPS_FILE))' apps/cli/package.json
  DEPS_FILE="$workspace_lock_deps" yq -i \
    '.importers."apps/cli".dependencies *= load(strenv(DEPS_FILE))' pnpm-lock.yaml
}

prepare_composition() {
  local bundle_name package_json
  local -a bundle_names=("$@")

  require_workspace
  if [ "${#bundle_names[@]}" -eq 0 ]; then
    for package_json in packages/bundle/*/package.json; do
      [ -f "$package_json" ] || continue
      bundle_name=$(yq -r '.name' "$package_json")
      [ -n "$bundle_name" ] || die "bundle package '$package_json' has no name"
      bundle_names+=("$bundle_name")
    done
  fi

  mkdir -p apps/nix-composition
  cp apps/cli/package.json apps/nix-composition/package.json

  yq -i '
    .name = "@deepseek-ai/dsh-nix-composition" |
    del(.devDependencies)
  ' apps/nix-composition/package.json
  yq -i '
    .importers."apps/nix-composition".dependencies =
      .importers."apps/cli".dependencies
  ' pnpm-lock.yaml

  for bundle_name in "${bundle_names[@]}"; do
    [ -n "$bundle_name" ] || die "composition bundle name cannot be empty"
    DSH_BUNDLE_NAME="$bundle_name" yq -i \
      'del(.dependencies[strenv(DSH_BUNDLE_NAME)])' \
      apps/nix-composition/package.json
    DSH_BUNDLE_NAME="$bundle_name" yq -i \
      'del(.importers."apps/nix-composition".dependencies[strenv(DSH_BUNDLE_NAME)])' \
      pnpm-lock.yaml
  done
}

case "$phase" in
  dependencies)
    patch_workspace_dependencies
    ;;
  composition)
    prepare_composition "$@"
    ;;
  *)
    die "unknown workspace patch phase '$phase'"
    ;;
esac
