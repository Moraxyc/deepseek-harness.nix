#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
package_set="$(nix eval --json ".#legacyPackages.${system}.ciPackageAttrs")"

all_attrs() {
  jq -r '
    (.packages, .bundles, .presets) | .[]
  ' <<< "$package_set"
}

if [ -z "$base_ref" ]; then
  all_attrs
  exit 0
fi

changed_files="$(git diff --name-only "$base_ref" HEAD -- .)"
if [ -z "$changed_files" ]; then
  exit 0
fi

global=0
changed_bundles=()
changed_presets=()
changed_packages=()
changed_unknown_packages=()

while IFS= read -r file; do
  case "$file" in
    lib/catalog.nix)
      ;;
    .github/workflows/package-ci.yml | default.nix | flake.nix | flake.lock | lib/* | modules/* | overlays/* | scripts/select-package-ci-attrs.sh | pkgs/dsh-kernel/* | pkgs/dsh-workspace/* | pkgs/dshBundleCheckHook/* | pkgs/dshWorkspacePatchHook/* | pkgs/importPnpmLock/*)
      global=1
      ;;
    pkgs/dsh/*)
      changed_packages+=("dsh")
      ;;
    pkgs/dsh-desktop/*)
      changed_packages+=("dsh-desktop")
      ;;
    pkgs/bundles/*)
      name="${file#pkgs/bundles/}"
      name="${name%%/*}"
      [ -n "$name" ] && changed_bundles+=("$name")
      ;;
    pkgs/presets/*)
      name="${file#pkgs/presets/}"
      name="${name%%/*}"
      [ -n "$name" ] && changed_presets+=("$name")
      ;;
    pkgs/*)
      name="${file#pkgs/}"
      name="${name%%/*}"
      case "$name" in
        dsh | dsh-desktop | dsh-kernel | dsh-workspace | dshWorkspacePatchHook)
          ;;
        *)
          changed_unknown_packages+=("$name")
          ;;
      esac
      ;;
  esac
done <<< "$changed_files"

for name in "${changed_unknown_packages[@]}"; do
  if ! jq -e --arg name "$name" '.packages | has($name)' <<< "$package_set" >/dev/null; then
    global=1
    break
  fi
  changed_packages+=("$name")
done

if [ "$global" -eq 1 ]; then
  all_attrs
  exit 0
fi

for name in "${changed_bundles[@]}"; do
  if ! jq -e --arg name "$name" '.bundles | has($name)' <<< "$package_set" >/dev/null; then
    global=1
    break
  fi
done

if [ "$global" -eq 1 ]; then
  all_attrs
  exit 0
fi

for name in "${changed_presets[@]}"; do
  if ! jq -e --arg name "$name" '.presets | has($name)' <<< "$package_set" >/dev/null; then
    global=1
    break
  fi
done

if [ "$global" -eq 1 ]; then
  all_attrs
  exit 0
fi

attrs=()

for name in "${changed_packages[@]}"; do
  if [ "$name" = "dsh" ]; then
    attrs+=(
      "$(jq -r '.packages.dsh' <<< "$package_set")"
      "$(jq -r '.packages["dsh-desktop"]' <<< "$package_set")"
    )
    while IFS= read -r preset; do
      attrs+=("$preset")
    done < <(jq -r '.presets[]' <<< "$package_set")
  else
    attrs+=("$(jq -r --arg name "$name" '.packages[$name]' <<< "$package_set")")
  fi
done

for name in "${changed_bundles[@]}"; do
  while IFS= read -r attr; do
    attrs+=("$attr")
  done < <(jq -r --arg name "$name" '.bundles[$name], (.bundleDependents[$name][]?)' <<< "$package_set")
done

for name in "${changed_presets[@]}"; do
  attrs+=("$(jq -r --arg name "$name" '.presets[$name]' <<< "$package_set")")
done

if [ "${#attrs[@]}" -gt 0 ]; then
  printf '%s\n' "${attrs[@]}" | sort -u
fi
