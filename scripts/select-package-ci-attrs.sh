#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
package_set="$(nix eval --json ".#legacyPackages.${system}.ciPackageAttrs")"

# A bundle build succeeds even when dsh would skip the bundle at runtime; its
# composition boots it through dshBundleCheckHook.
all_attrs() {
  jq -r '
    (.packages, .bundles, .presets, .bundleCompositions) | .[]
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
lock_changed=0
changed_bundles=()
changed_presets=()
changed_packages=()
changed_unknown_packages=()

record_source_package() {
  local name="$1"
  case "$name" in
    dsh-workspace | dsh-runtime)
      global=1
      ;;
    bundles.*)
      local bundle="${name#bundles.}"
      if [ -n "$bundle" ]; then
        changed_bundles+=("$bundle")
      else
        global=1
      fi
      ;;
    *)
      if [ -n "$name" ]; then
        changed_unknown_packages+=("$name")
      else
        global=1
      fi
      ;;
  esac
}

changed_lock_packages() {
  {
    git show "${base_ref}:_sources/lock.json" 2>/dev/null \
      && printf '\n' \
      && git show "HEAD:_sources/lock.json" 2>/dev/null
  } | jq -r -s '
    if length != 2 then error("expected two lockfiles") else . end
    | .[0] as $old
    | .[1] as $new
    | if ($old | type) != "object" or ($new | type) != "object"
        or ($old.packages | type) != "object" or ($new.packages | type) != "object"
        or (($old | del(.packages)) != ($new | del(.packages))) then
        error("lockfile metadata changed")
      else
        [($old.packages | keys_unsorted[]), ($new.packages | keys_unsorted[])]
        | unique[]
        | . as $k
        | select(
            (($old.packages | has($k)) != ($new.packages | has($k)))
            or ($old.packages[$k] != $new.packages[$k])
          )
      end
  ' 2>/dev/null
}

while IFS= read -r file; do
  case "$file" in
    lib/catalog.nix | fetchrix.toml)
      ;;
    .github/workflows/package-ci.yml | default.nix | flake.nix | flake.lock | lib/* | modules/* | overlays/* | scripts/select-package-ci-attrs.sh | scripts/default.nix | scripts/nix-run | scripts/generate-optional-bundles.sh | _sources/dsh-workspace/* | pkgs/dsh-runtime/* | pkgs/dsh-workspace/* | pkgs/dshBundleCheckHook/* | pkgs/importPnpmLock/*)
      global=1
      ;;
    _sources/lock.json)
      lock_changed=1
      ;;
    pkgs/dsh/*)
      changed_packages+=("dsh")
      ;;
    pkgs/bundles/*)
      name="${file#pkgs/bundles/}"
      name="${name%%/*}"
      [ -n "$name" ] && changed_bundles+=("$name")
      ;;
    _sources/*)
      name="${file#_sources/}"
      name="${name%%/*}"
      record_source_package "$name"
      ;;
    pkgs/presets/*)
      name="${file#pkgs/presets/}"
      name="${name%%/*}"
      [ -n "$name" ] && changed_presets+=("$name")
      ;;
    pkgs/*)
      name="${file#pkgs/}"
      name="${name%%/*}"
      changed_unknown_packages+=("$name")
      ;;
  esac
done <<< "$changed_files"

if [ "$global" -eq 0 ] && [ "$lock_changed" -eq 1 ]; then
  if ! lock_keys="$(changed_lock_packages)"; then
    global=1
  else
    while IFS= read -r key; do
      [ -n "$key" ] || continue
      record_source_package "$key"
      [ "$global" -eq 1 ] && break
    done <<< "$lock_keys"
  fi
fi

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
    # Both desktop variants embed the composed dsh as their runtime.
    attrs+=(
      "$(jq -r '.packages.dsh' <<< "$package_set")"
      "$(jq -r '.packages["dsh-desktop"]' <<< "$package_set")"
      "$(jq -r '.packages["dsh-desktop-official"]' <<< "$package_set")"
      "$(jq -r '.packages["dsh-desktop-unofficial"]' <<< "$package_set")"
    )
    while IFS= read -r attr; do
      attrs+=("$attr")
    done < <(jq -r '.presets[], .bundleCompositions[]' <<< "$package_set")
  else
    attrs+=("$(jq -r --arg name "$name" '.packages[$name]' <<< "$package_set")")
  fi
done

for name in "${changed_bundles[@]}"; do
  while IFS= read -r attr; do
    attrs+=("$attr")
  done < <(jq -r --arg name "$name" '.bundles[$name], (.bundleCompositions[$name] // empty), (.bundleDependents[$name][]?)' <<< "$package_set")
done

for name in "${changed_presets[@]}"; do
  attrs+=("$(jq -r --arg name "$name" '.presets[$name]' <<< "$package_set")")
done

if [ "${#attrs[@]}" -gt 0 ]; then
  printf '%s\n' "${attrs[@]}" | sort -u
fi
