#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq nix
# shellcheck shell=bash
set -euo pipefail

src=${1?"usage: update.sh <workspace-source>"}
pin="$(dirname "${BASH_SOURCE[0]}")/source.json"

version="$(jq -er '.version | strings' "$src/packages/experimental/cua-macos/package.json")"
url="https://registry.npmjs.org/@deepseek-ai/dsh-experimental-cua-macos/-/dsh-experimental-cua-macos-$version.tgz"
hash="$(nix store prefetch-file --json --hash-type sha512 "$url" | jq -er .hash)"

jq -n --arg version "$version" --arg url "$url" --arg hash "$hash" \
  '{version: $version, url: $url, hash: $hash}' > "$pin"
printf 'dsh-cua-native: pinned %s\n' "$version"
