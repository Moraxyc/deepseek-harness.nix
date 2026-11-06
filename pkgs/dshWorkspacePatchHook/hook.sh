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
    apps/desktop-host/package.json \
    pnpm-lock.yaml \
    pnpm-workspace.yaml
  do
    if [ ! -f "$path" ]; then
      dshWorkspaceDie "workspace patch expected file '$path'"
      return 1
    fi
  done
}

# Declare the upstream installation as one importer: the dsh CLI and the
# private Desktop Host, plus every required peer that npm would install. pnpm
# deploy alone omits those peers because the workspace disables autoInstallPeers.
dshWorkspacePrepareRuntime() {
  local lock_deps manifests package_paths runtime_deps source_lock_deps workspace_overrides

  dshWorkspaceRequire || return
  manifests="$TMPDIR/dsh-workspace-manifests.json"
  package_paths="$TMPDIR/dsh-workspace-package-paths.json"
  runtime_deps="$TMPDIR/dsh-workspace-runtime-dependencies.json"
  source_lock_deps="$TMPDIR/dsh-workspace-source-lock-dependencies.json"
  lock_deps="$TMPDIR/dsh-workspace-runtime-lock-dependencies.json"

  yq ea -o=json -I=0 '
    (
      select(.name != null)
      | (.peerDependenciesMeta // {}) as $meta
      | {(.name): {
          "path": (filename | sub("/package.json$"; "")),
          "dependencies": (.dependencies // {}),
          "peers": ((.peerDependencies // {})
            | with_entries(select(($meta[.key].optional // false) != true)))
        }}
    ) as $item ireduce ({}; . * $item)
  ' apps/*/package.json vendor/*/package.json packages/*/*/package.json > "$manifests" || return
  jq -c 'map_values(.path)' "$manifests" > "$package_paths" || return

  : "${DSH_WORKSPACE_OVERRIDES:?dsh-workspace: DSH_WORKSPACE_OVERRIDES must point to the workspace overrides JSON}"
  workspace_overrides="$DSH_WORKSPACE_OVERRIDES"

  # Workspace dependencies are followed only to find their peers; pnpm installs
  # external dependencies transitively.
  jq -c '
    . as $manifests
    | def step:
        reduce (keys[] | select($manifests[.] != null)) as $name (.;
          ($manifests[$name].dependencies | with_entries(select($manifests[.key] != null)))
          * $manifests[$name].peers
          * .);
    {"@deepseek-ai/dsh": "workspace:*", "@deepseek-ai/dsh-desktop-host": "workspace:*"}
    | until(. as $current | step == $current; step)
  ' "$manifests" > "$runtime_deps" || return

  yq -o=json -I=0 '
    [.importers[] | (.devDependencies // {}) * (.dependencies // {})] | .[] as $item ireduce ({}; . * $item)
  ' pnpm-lock.yaml > "$source_lock_deps"

  # Workspace links are importer-relative. Rebuild them for apps/nix-runtime
  # while retaining upstream link: overrides and external lock entries.
  RUNTIME_DEPS="$runtime_deps" PACKAGE_PATHS="$package_paths" \
    SOURCE_LOCK_DEPS="$source_lock_deps" WORKSPACE_OVERRIDES="$workspace_overrides" \
    yq -n -o=json -I=0 '
      load(strenv(RUNTIME_DEPS)) as $dependencies
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
                    // $dependency.value
                  ),
                  "version": "link:../../" + $paths[$dependency.key]
                } | select($paths[$dependency.key] != null))
                // $source[$dependency.key]
              )
            }
        )
      | from_entries
    ' > "$lock_deps"

  if ! yq -e '
    to_entries
    | map(select(
        .value == null
        or .value.specifier == null
        or .value.version == null
      ))
    | length == 0
  ' "$lock_deps" >/dev/null; then
    dshWorkspaceDie "runtime dependency is missing from the workspace lockfile"
    return 1
  fi

  mkdir -p apps/nix-runtime
  LOCK_DEPS="$lock_deps" yq -n -o=json '{
    "name": "@deepseek-ai/dsh-nix-runtime",
    "version": "0.0.0",
    "private": true,
    "dependencies": (load(strenv(LOCK_DEPS)) | with_entries(.value = .value.specifier))
  }' > apps/nix-runtime/package.json

  LOCK_DEPS="$lock_deps" yq -i '
    .importers."apps/nix-runtime" = {
      "dependencies": load(strenv(LOCK_DEPS))
    }
  ' pnpm-lock.yaml
}

patchDshWorkspace() {
  local phase=${1:-}
  shift || true

  case "$phase" in
    runtime)
      dshWorkspacePrepareRuntime
      ;;
    *)
      dshWorkspaceDie "unknown workspace patch phase '$phase'"
      ;;
  esac
}
