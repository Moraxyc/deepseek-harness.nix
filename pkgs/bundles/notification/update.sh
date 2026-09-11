#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils git nix nix-update yq-go
# shellcheck shell=bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

attr="${UPDATE_NIX_ATTR_PATH:-legacyPackages.$(nix eval --raw --impure --expr 'builtins.currentSystem').bundles.notification}"
case "$attr" in
  packages.*)
    attr="${attr#*.}"
    attr="${attr#*.}"
    ;;
esac

nix-update \
  --flake \
  --src-only \
  --override-filename=pkgs/bundles/notification/package.nix \
  "$attr"

src="$(nix build --no-link --print-out-paths ".#$attr.src")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# The release lockfile links peers to the author's DSH checkout, which the
# pinned kernel supplies instead; keep the vendored lockfile matching that.
yq -o=json '
  .importers.".".devDependencies |= with_entries(
    select(.key | test("^@deepseek-ai/") | not)
  )
' "$src/pnpm-lock.yaml" > "$tmp_dir/pnpm-lock.json"
mv "$tmp_dir/pnpm-lock.json" pkgs/bundles/notification/pnpm-lock.json
yq -o=json . "$src/pnpm-workspace.yaml" > "$tmp_dir/pnpm-workspace.json"
mv "$tmp_dir/pnpm-workspace.json" pkgs/bundles/notification/pnpm-workspace.json
