#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils git nix nix-update yq-go
# shellcheck shell=bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

attr="${UPDATE_NIX_ATTR_PATH:-bundles.web-ui}"
case "$attr" in
  packages.* | legacyPackages.*)
    attr="${attr#*.}"
    attr="${attr#*.}"
    ;;
esac

nix-update \
  --flake \
  --src-only \
  --override-filename=pkgs/bundles/web-ui/package.nix \
  "$attr"

src="$(nix build --no-link --print-out-paths ".#$attr.src")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

yq -o=json . "$src/pnpm-lock.yaml" > "$tmp_dir/pnpm-lock.json"
mv "$tmp_dir/pnpm-lock.json" pkgs/bundles/web-ui/pnpm-lock.json
