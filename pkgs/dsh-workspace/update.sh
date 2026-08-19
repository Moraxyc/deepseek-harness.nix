#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils gnused nix-update yq-go
# shellcheck shell=bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

attr="${UPDATE_NIX_ATTR_PATH:-dsh-workspace}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

old_src="$(nix eval --raw ".#$attr.src.rev" 2>/dev/null)"

nix-update --flake --version=branch --src-only "$attr"

new_src="$(nix eval --raw ".#$attr.src.rev" 2>/dev/null)"

if [ "$old_src" = "$new_src" ]; then
  printf 'dsh-workspace: src unchanged (%s); skipping pnpm-lock regeneration\n' "$old_src"
  exit 0
fi

src="$(nix build --no-link --print-out-paths ".#$attr.src")"

yq -o=json . "$src/pnpm-lock.yaml" > "$tmp_dir/pnpm-lock.json"
mv "$tmp_dir/pnpm-lock.json" "$repo_root/pkgs/dsh-workspace/pnpm-lock.json"

new_deps="$(nix build --no-link --print-out-paths ".#$attr.pnpmDeps")"
new_hash="$(nix hash path --type sha256 "$new_deps")"

if old_output="$(nix build --no-link --print-out-paths ".#$attr.fetchPnpmDeps" 2>&1)"; then
  old_deps="$(printf '%s\n' "$old_output" | tail -n1)"
  old_hash="$(nix hash path --type sha256 "$old_deps")"
else
  old_hash="$(printf '%s\n' "$old_output" | sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]\{1,\}\).*/\1/p' | tail -n1)"
fi

if [ -z "$old_hash" ]; then
  printf 'dsh-workspace: could not determine fetchPnpmDeps output hash\n' >&2
  exit 1
fi

if [ "$new_hash" != "$old_hash" ]; then
  printf 'dsh-workspace: pnpmDeps hash %s does not match fetchPnpmDeps hash %s\n' "$new_hash" "$old_hash" >&2
  exit 1
fi

printf 'dsh-workspace: generated pnpmDeps matches fetchPnpmDeps (%s)\n' "$new_hash"
