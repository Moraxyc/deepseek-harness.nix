# shellcheck shell=bash
# Prints the package attrs CI builds for the changes since BASE_REF, or every
# attr without BASE_REF: select-package-ci-attrs [BASE_REF]

base_ref="${1:-}"
cd "$(git rev-parse --show-toplevel)" || exit
system=$(nix eval --raw --impure --expr builtins.currentSystem)
package_set=$(nix eval --json ".#legacyPackages.$system.ciPackageAttrs")

# The first path component of FILE below DIR.
name_under() {
  local rest="${1#"$2"/}"
  printf '%s\n' "${rest%%/*}"
}

# A `source KEY` line for each lock.json package that differs between BASE_REF
# and HEAD. Fails when anything else changed or either side is missing.
changed_lock_sources() {
  { git show "$base_ref:_sources/lock.json" && git show HEAD:_sources/lock.json; } 2>/dev/null |
    jq -rs '
      if length != 2 or (.[0] | del(.packages)) != (.[1] | del(.packages)) then
        error("lockfile metadata changed")
      end
      | .[0].packages as $old | .[1].packages as $new
      | [$old, $new | keys[]] | unique[] | select($old[.] != $new[.]) | "source \(.)"
    '
}

# Prints what a changed file affects: `global`, or `KIND NAME` where KIND is
# package, bundle, preset, or source (a fetchrix package key).
classify() {
  local file="$1"
  case "$file" in
    # Maintenance tools that Package CI builds as checks.
    lib/catalog.nix | fetchrix.toml | pkgs/dsh-bump-report/*) ;;
    .github/workflows/package-ci.yml | default.nix | flake.nix | flake.lock | lib/* | modules/* | overlays/* | \
      scripts/select-package-ci-attrs.sh | scripts/default.nix | scripts/nix-run | scripts/generate-optional-bundles.sh | \
      pkgs/dsh-runtime/* | pkgs/dsh-workspace/* | pkgs/dsh-profile-smoke/* | pkgs/importPnpmLock/*)
      echo global
      ;;
    _sources/lock.json) changed_lock_sources || echo global ;;
    _sources/*) echo "source $(name_under "$file" _sources)" ;;
    pkgs/dsh/*) echo "package dsh" ;;
    pkgs/bundles/*) echo "bundle $(name_under "$file" pkgs/bundles)" ;;
    pkgs/presets/*) echo "preset $(name_under "$file" pkgs/presets)" ;;
    pkgs/*) echo "package $(name_under "$file" pkgs)" ;;
  esac
}

if [ -z "$base_ref" ]; then
  echo global
else
  git diff --name-only "$base_ref" HEAD -- . | while IFS= read -r file; do classify "$file"; done
fi | jq -nrR --argjson set "$package_set" '
  def source:
    if .name == "dsh-workspace" or .name == "dsh-runtime" then {kind: "global"}
    elif .name | startswith("bundles.") then {kind: "bundle", name: .name[8:]}
    else {kind: "package", name} end;
  def known: .name as $name | $set[{package: "packages", bundle: "bundles", preset: "presets"}[.kind]] | has($name);
  def attrs:
    if .kind == "package" and .name == "dsh" then
      # Both desktop variants embed the composed dsh as their runtime.
      $set.packages["dsh", "dsh-desktop", "dsh-desktop-official", "dsh-desktop-unofficial"],
      $set.presets[], $set.bundleCompositions[]
    elif .kind == "package" then $set.packages[.name]
    # A bundle build succeeds even when dsh would skip the bundle at runtime;
    # its composition boots it through dsh-profile-smoke.
    elif .kind == "bundle" then $set.bundles[.name], ($set.bundleCompositions[.name] // empty), $set.bundleDependents[.name][]?
    else $set.presets[.name] end;
  [inputs | split(" ") | {kind: .[0], name: .[1]} | if .kind == "source" then source end] as $changes
  | if all($changes[]; .kind != "global" and known) then [$changes[] | attrs]
    else [$set.packages, $set.bundles, $set.presets, $set.bundleCompositions | .[]] end
  | unique[]
'
