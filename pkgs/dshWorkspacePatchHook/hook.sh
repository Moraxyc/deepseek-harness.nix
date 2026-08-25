#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2016

dshWorkspaceDie() {
  printf 'dsh-workspace: %s\n' "$1" >&2
  return 1
}

dshWorkspaceRequire() {
  local path

  for path in \
    apps/cli/package.json \
    packages/bundle/base/package.json \
    pnpm-lock.yaml \
    pnpm-workspace.yaml
  do
    if [ ! -f "$path" ]; then
      dshWorkspaceDie "workspace patch expected file '$path'"
      return 1
    fi
  done
}

dshWorkspacePrepareKernel() {
  local base_deps bundle_names kernel_dep_count kernel_deps kernel_peers lock_deps package_paths source_lock_deps workspace_overrides

  dshWorkspaceRequire || return
  bundle_names="$TMPDIR/dsh-workspace-bundle-names.json"
  package_paths="$TMPDIR/dsh-workspace-package-paths.json"
  base_deps="$TMPDIR/dsh-workspace-base-dependencies.json"
  kernel_deps="$TMPDIR/dsh-workspace-kernel-dependencies.json"
  kernel_peers="$TMPDIR/dsh-workspace-kernel-peers.json"
  source_lock_deps="$TMPDIR/dsh-workspace-source-lock-dependencies.json"
  lock_deps="$TMPDIR/dsh-workspace-kernel-lock-dependencies.json"
  workspace_overrides="$TMPDIR/dsh-workspace-overrides.json"

  yq ea -o=json -I=0 '
    select(.name != null)
    | {(.name): (filename | sub("/package.json$"; ""))}
      as $item ireduce ({}; . * $item)
  ' vendor/*/package.json packages/*/*/package.json > "$package_paths"

  yq ea -o=json -I=0 '
    select(.dsh.bundle != null)
    | {(.name): true}
      as $item ireduce ({}; . * $item)
  ' packages/*/*/package.json > "$bundle_names"

  yq -o=json -I=0 '.overrides // {}' pnpm-workspace.yaml > "$workspace_overrides"

  yq -o=json -I=0 '
    (.peerDependenciesMeta // {}) as $meta
    | (.dependencies // {})
      * ((.peerDependencies // {})
        | with_entries(select(($meta[.key].optional // false) != true)))
  ' packages/bundle/base/package.json > "$base_deps"

  # Bundle manifests stay outside the kernel; the CLI and base runtime remain
  # shared so their required peers resolve to one workspace instance.
  BUNDLE_NAMES="$bundle_names" BASE_DEPS="$base_deps" \
    yq -o=json -I=0 '
      ((.dependencies // {})
        | with_entries(select(load(strenv(BUNDLE_NAMES))[.key] != true)))
      * load(strenv(BASE_DEPS))
    ' apps/cli/package.json > "$kernel_deps"

  while :; do
    kernel_dep_count=$(yq '. | length' "$kernel_deps")
    KERNEL_DEPS="$kernel_deps" yq ea -o=json -I=0 '
      (
        select(.name as $name | load(strenv(KERNEL_DEPS))[$name] != null)
        | (.peerDependenciesMeta // {}) as $meta
        | ((.peerDependencies // {})
          | with_entries(select(($meta[.key].optional // false) != true)))
      ) as $item ireduce ({}; . * $item)
    ' vendor/*/package.json packages/*/*/package.json > "$kernel_peers"

    KERNEL_PEERS="$kernel_peers" yq -i '
      . = load(strenv(KERNEL_PEERS)) * .
    ' "$kernel_deps"
    [ "$(yq '. | length' "$kernel_deps")" -eq "$kernel_dep_count" ] && break
  done

  mkdir -p apps/nix-kernel
  cp apps/cli/package.json apps/nix-kernel/package.json
  KERNEL_DEPS="$kernel_deps" yq -i '
    .name = "@deepseek-ai/dsh-nix-kernel"
    | .private = true
    | .dependencies = load(strenv(KERNEL_DEPS))
    | del(
        .bin,
        .devDependencies,
        .optionalDependencies,
        .peerDependencies,
        .peerDependenciesMeta,
        .scripts
      )
  ' apps/nix-kernel/package.json

  yq -o=json -I=0 '
    (.importers."apps/cli".dependencies // {})
    * (.importers."packages/bundle/base".dependencies // {})
    * (.importers."packages/bundle/base".devDependencies // {})
  ' pnpm-lock.yaml > "$source_lock_deps"

  # Workspace links are importer-relative. Rebuild them for apps/nix-kernel
  # while retaining upstream link: overrides and external lock entries.
  KERNEL_DEPS="$kernel_deps" PACKAGE_PATHS="$package_paths" \
    SOURCE_LOCK_DEPS="$source_lock_deps" WORKSPACE_OVERRIDES="$workspace_overrides" \
    yq -o=json -I=0 '
      load(strenv(KERNEL_DEPS)) as $dependencies
      | load(strenv(PACKAGE_PATHS)) as $paths
      | load(strenv(SOURCE_LOCK_DEPS)) as $source
      | load(strenv(WORKSPACE_OVERRIDES)) as $overrides
      | $dependencies
      | to_entries
      | map(
          . as $dependency
          | {
              "key": .key,
              "value": (
                ({
                  "specifier": (
                    (
                      "link:../../" + ($paths[$dependency.key] // "")
                      | select((($overrides[$dependency.key] // "") | test("^link:")))
                    )
                    // ($source[$dependency.key].specifier // $dependency.value)
                  ),
                  "version": "link:../../" + $paths[$dependency.key]
                } | select($paths[$dependency.key] != null))
                // $source[$dependency.key]
              )
            }
        )
      | from_entries
    ' apps/cli/package.json > "$lock_deps"

  if ! yq -e '
    to_entries
    | map(select(
        .value == null
        or .value.specifier == null
        or .value.version == null
      ))
    | length == 0
  ' "$lock_deps" >/dev/null; then
    dshWorkspaceDie "kernel dependency is missing from the workspace lockfile"
    return 1
  fi

  LOCK_DEPS="$lock_deps" yq -i '
    .importers."apps/nix-kernel" = {
      "dependencies": load(strenv(LOCK_DEPS))
    }
  ' pnpm-lock.yaml
}

patchDshWorkspace() {
  local phase=${1:-}
  shift || true

  case "$phase" in
    kernel)
      dshWorkspacePrepareKernel
      ;;
    *)
      dshWorkspaceDie "unknown workspace patch phase '$phase'"
      ;;
  esac
}
