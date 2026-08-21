#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils git gnused jq nix nix-update yq-go
# shellcheck shell=bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

attr="${UPDATE_NIX_ATTR_PATH:-dsh-workspace}"
if [[ "$attr" == packages.* ]]; then
  attr="${attr#packages.}"
  attr="${attr#*.}"
fi
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

old_src="$(nix-instantiate --eval --raw --expr \
  "(builtins.getFlake (toString ./.)).packages.\${builtins.currentSystem}.$attr.src.rev" \
  2>/dev/null)"

if [[ "$old_src" == refs/tags/* ]]; then
  old_src="$(git ls-remote \
    https://github.com/deepseek-ai/deepseek-harness.git \
    "$old_src" | cut -f1)"
fi

nix-update \
  --flake \
  --version=unstable \
  --src-only \
  --override-filename=pkgs/dsh-workspace/package.nix \
  "$attr"

new_src="$(nix-instantiate --eval --raw --expr \
  "(builtins.getFlake (toString ./.)).packages.\${builtins.currentSystem}.$attr.src.rev" \
  2>/dev/null)"

if [[ "$new_src" == refs/tags/* ]]; then
  new_src="$(git ls-remote \
    https://github.com/deepseek-ai/deepseek-harness.git \
    "$new_src" | cut -f1)"

  sed -i \
    "s|^  env\\.DSH_CLIENT_COMMIT_HASH = .*;$|  env.DSH_CLIENT_COMMIT_HASH = \"$new_src\";|" \
    pkgs/dsh-workspace/package.nix
fi

if [ "$old_src" = "$new_src" ]; then
  printf 'dsh-workspace: src unchanged (%s); skipping pnpm-lock regeneration\n' "$old_src"
  exit 0
fi

src="$(nix build --no-link --print-out-paths ".#$attr.src")"

landlock_version="$(jq -er '.version | strings' "$src/native/landlock-run/package.json")"
nix-update \
  --flake \
  --version="$landlock_version" \
  --no-src \
  --override-filename=pkgs/dsh-landlock-run/package.nix \
  dsh-landlock-run

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
