#!/usr/bin/env bash

dshWorkspaceDie() {
  printf 'dsh-workspace: %s\n' "$1" >&2
  return 1
}

dshWorkspaceRequire() {
  local path

  for path in \
    apps/cli/package.json \
    pnpm-lock.yaml \
    vendor/group/package.json
  do
    if [ ! -f "$path" ]; then
      dshWorkspaceDie "workspace patch expected file '$path'"
      return 1
    fi
  done

  if [ ! -d packages/bundle ]; then
    dshWorkspaceDie "workspace patch expected directory 'packages/bundle'"
    return 1
  fi
}

dshWorkspacePatchDependencies() {
  local workspace_deps workspace_lock_deps

  dshWorkspaceRequire || return
  workspace_deps="$TMPDIR/dsh-workspace-dependencies.json"
  workspace_lock_deps="$TMPDIR/dsh-workspace-lock-dependencies.json"

  yq ea -o=json -I=0 \
    "(select(.name | test(\"^@deepseek-ai/\")) | {
      (.name): \"workspace:^\"
    }) as \$item ireduce ({}; . * \$item)" \
    vendor/group/package.json packages/*/*/package.json > "$workspace_deps"
  yq ea -o=json -I=0 \
    "(select(.name | test(\"^@deepseek-ai/\")) | {
      (.name): {
        \"specifier\": \"workspace:^\",
        \"version\": \"link:\" + (filename | sub(\"/package.json\$\"; \"\") | sub(\"^\"; \"../../\"))
      }
    }) as \$item ireduce ({}; . * \$item)" \
    vendor/group/package.json packages/*/*/package.json > "$workspace_lock_deps"
  DEPS_FILE="$workspace_deps" yq -i \
    '.dependencies *= load(strenv(DEPS_FILE))' apps/cli/package.json
  DEPS_FILE="$workspace_lock_deps" yq -i \
    '.importers."apps/cli".dependencies *= load(strenv(DEPS_FILE))' pnpm-lock.yaml
}

dshWorkspacePrepareComposition() {
  local bundle_name package_json
  local -a bundle_names=("$@")

  dshWorkspaceRequire || return
  if [ "${#bundle_names[@]}" -eq 0 ]; then
    for package_json in packages/bundle/*/package.json; do
      [ -f "$package_json" ] || continue
      bundle_name=$(yq -r '.name' "$package_json")
      [ -n "$bundle_name" ] || {
        dshWorkspaceDie "bundle package '$package_json' has no name"
        return 1
      }
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
    [ -n "$bundle_name" ] || {
      dshWorkspaceDie "composition bundle name cannot be empty"
      return 1
    }
    DSH_BUNDLE_NAME="$bundle_name" yq -i \
      'del(.dependencies[strenv(DSH_BUNDLE_NAME)])' \
      apps/nix-composition/package.json
    DSH_BUNDLE_NAME="$bundle_name" yq -i \
      'del(.importers."apps/nix-composition".dependencies[strenv(DSH_BUNDLE_NAME)])' \
      pnpm-lock.yaml
  done
}

patchDshWorkspace() {
  local phase=${1:-}
  shift || true

  case "$phase" in
    dependencies)
      dshWorkspacePatchDependencies
      ;;
    composition)
      dshWorkspacePrepareComposition "$@"
      ;;
    *)
      dshWorkspaceDie "unknown workspace patch phase '$phase'"
      ;;
  esac
}
