#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils gnused jq nix nix-update yq-go
# shellcheck shell=bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

attr="${UPDATE_NIX_ATTR_PATH:-dsh-workspace}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

old_src="$(nix eval --raw ".#$attr.src.rev" 2>/dev/null)"

nix-update --flake --version=unstable --src-only "$attr"

new_src="$(nix eval --raw ".#$attr.src.rev" 2>/dev/null)"

if [ "$old_src" = "$new_src" ]; then
  printf 'dsh-workspace: src unchanged (%s); skipping pnpm-lock regeneration\n' "$old_src"
  exit 0
fi

src="$(nix build --no-link --print-out-paths ".#$attr.src")"

landlock_version="$(jq -er '.version | strings' "$src/native/landlock-run/package.json")"
nix-update --flake --version="$landlock_version" --no-src dsh-landlock-run

yq -o=json . "$src/pnpm-lock.yaml" > "$tmp_dir/pnpm-lock.json"
mv "$tmp_dir/pnpm-lock.json" "$repo_root/pkgs/dsh-workspace/pnpm-lock.json"

new_deps="$(nix build --no-link --print-out-paths ".#$attr.pnpmDeps")"
new_hash="$(nix hash path --type sha256 "$new_deps")"

EXPECTED_PNPM_HASH="$new_hash" nix build --impure --no-link --print-out-paths --expr '
  let
    flake = builtins.getFlake (toString ./.);
    package = flake.packages.${builtins.currentSystem}.dsh-workspace;
  in
  package.passthru.fetchPnpmDeps.overrideAttrs (_: {
    outputHash = builtins.getEnv "EXPECTED_PNPM_HASH";
  })
' >/dev/null

printf 'dsh-workspace: pnpmDeps matches fetchPnpmDeps (%s)\n' "$new_hash"
