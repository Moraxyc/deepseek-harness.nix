#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# shellcheck disable=SC2016
package_set="$(
  nix eval --impure --json --expr '
    let
      f = import ./default.nix;
      system = builtins.currentSystem;
      isDerivation = p: builtins.isAttrs p && (p.type or null) == "derivation";
      names = set: builtins.filter (name: isDerivation (builtins.getAttr name set)) (builtins.attrNames set);
      packages = builtins.filter (name: name != "default") (names f.packages.${system});
      bundles = names f.legacyPackages.${system}.bundles;
      presets = names f.legacyPackages.${system}.presets;
    in
    { inherit packages bundles presets; }
  '
)"

all_attrs() {
  jq -r '
    (.packages[] | ".#" + .),
    (.bundles[] | ".#bundles." + .),
    (.presets[] | ".#presets." + .)
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
  if ! jq -e --arg name "$name" '.packages | index($name)' <<< "$package_set" >/dev/null; then
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
  if ! jq -e --arg name "$name" '.bundles | index($name)' <<< "$package_set" >/dev/null; then
    global=1
    break
  fi
done

if [ "$global" -eq 1 ]; then
  all_attrs
  exit 0
fi

for name in "${changed_presets[@]}"; do
  if ! jq -e --arg name "$name" '.presets | index($name)' <<< "$package_set" >/dev/null; then
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
    attrs+=(".#dsh" ".#dsh-desktop")
    while IFS= read -r preset; do
      attrs+=(".#presets.$preset")
    done < <(jq -r '.presets[]' <<< "$package_set")
  else
    attrs+=(".#$name")
  fi
done

for name in "${changed_bundles[@]}"; do
  attrs+=(".#bundles.$name")
done

if [ "${#changed_bundles[@]}" -gt 0 ]; then
  changed_json="$(
    printf '%s\n' "${changed_bundles[@]}" |
      jq -Rsc 'split("\n") | map(select(. != ""))'
  )"
  # shellcheck disable=SC2016
  affected="$(
    CHANGED_BUNDLES="$changed_json" nix eval --impure --json --expr '
      let
        f = import ./default.nix;
        system = builtins.currentSystem;
        changed = builtins.fromJSON (builtins.getEnv "CHANGED_BUNDLES");
        isDerivation = p: builtins.isAttrs p && (p.type or null) == "derivation";
        packages = f.packages.${system};
        legacy = f.legacyPackages.${system};
        packageNames = builtins.filter (name: name != "default" && isDerivation packages.${name}) (builtins.attrNames packages);
        presetNames = builtins.filter (name: isDerivation legacy.presets.${name}) (builtins.attrNames legacy.presets);
        changedPnames = map (name: legacy.bundles.${name}.pname) changed;
        usesChanged = p: builtins.any (bundle: builtins.elem (bundle.pname or bundle.name or null) changedPnames) (p.passthru.composedBundles or []);
        affectedPackages = builtins.filter (name: usesChanged packages.${name}) packageNames;
        affectedPresets = builtins.filter (name: usesChanged legacy.presets.${name}) presetNames;
      in
      { inherit affectedPackages affectedPresets; }
    '
  )"
  while IFS= read -r attr; do
    attrs+=("$attr")
  done < <(
    jq -r '
      (.affectedPackages[] | ".#" + .),
      (if (.affectedPackages | index("dsh")) != null then ".#dsh-desktop" else empty end),
      (.affectedPresets[] | ".#presets." + .)
    ' <<< "$affected"
  )
fi

for name in "${changed_presets[@]}"; do
  attrs+=(".#presets.$name")
done

if [ "${#attrs[@]}" -gt 0 ]; then
  printf '%s\n' "${attrs[@]}" | sort -u
fi
