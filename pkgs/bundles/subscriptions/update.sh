#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils git nix nix-update yq-go
# shellcheck shell=bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

attr="${UPDATE_NIX_ATTR_PATH:-legacyPackages.$(nix eval --raw --impure --expr 'builtins.currentSystem').bundles.subscriptions}"
case "$attr" in
  packages.*)
    attr="${attr#*.}"
    attr="${attr#*.}"
    ;;
esac

nix-update \
  --flake \
  --src-only \
  --override-filename=pkgs/bundles/subscriptions/package.nix \
  "$attr"

src="$(nix build --no-link --print-out-paths ".#$attr.src")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Keep only the Harness peers the pinned kernel does not supply; the release
# lockfile references the author's checkout for the rest. postPatch applies the
# same filter to the source tree.
yq -o=json '
  .importers.".".devDependencies |= with_entries(
    select(
      (.key | test("^@deepseek-ai/") | not)
      or (.key | test("@deepseek-ai/(cordis|dsh-attachment|dsh-home-paths|dsh-llm|dsh-tools|schemastery)"))
    )
  )
' "$src/pnpm-lock.yaml" > "$tmp_dir/pnpm-lock.json"
mv "$tmp_dir/pnpm-lock.json" pkgs/bundles/subscriptions/pnpm-lock.json
