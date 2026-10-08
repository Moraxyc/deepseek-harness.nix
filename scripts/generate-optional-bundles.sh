#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils diffutils findutils gawk gnugrep gnused jq
# shellcheck shell=bash
set -euo pipefail

# Regenerate pkgs/dsh-workspace/optional-bundles.json from upstream OPTIONAL_BUNDLES.

usage='usage: generate-optional-bundles.sh <upstream-source-root> [output]'
src=${1?"$usage"}
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest=${2:-"$repo_root/pkgs/dsh-workspace/optional-bundles.json"}

fail() {
  printf 'generate-optional-bundles: %s\n' "$1" >&2
  exit 1
}

profile_ts="$src/packages/boot/app-boot/src/profile.ts"
cli_manifest="$src/apps/cli/package.json"
for required in "$profile_ts" "$cli_manifest"; do
  if [ ! -f "$required" ]; then
    fail "missing $required; is this an upstream source tree?"
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# profile.ts imports the rest of the launcher, so it is scanned, not evaluated.
declaration_body() {
  awk -v name="$1" -v close_line="$2" '
    $0 ~ ("^export const " name "[^A-Za-z0-9_$]") { inside = 1; next }
    inside && $0 ~ close_line { closed = 1; exit }
    inside { print }
    END { exit !closed }
  ' "$profile_ts"
}

# Reject unfamiliar declaration syntax rather than silently omitting packages.
body="$(declaration_body OPTIONAL_BUNDLES '^]')" ||
  fail 'OPTIONAL_BUNDLES is missing or unterminated'
blank_re='^[[:space:]]*(//.*)?$'
entry_re="^[[:space:]]*[\"'](@deepseek-ai/[a-z0-9][a-z0-9-]*)[\"'],?[[:space:]]*(//.*)?\$"
: > "$tmp_dir/names"
while IFS= read -r line; do
  [[ $line =~ $blank_re ]] && continue
  [[ $line =~ $entry_re ]] || fail "unexpected OPTIONAL_BUNDLES line: $line"
  printf '%s\n' "${BASH_REMATCH[1]}" >> "$tmp_dir/names"
done <<< "$body"
sort -u -o "$tmp_dir/names" "$tmp_dir/names"
if [ ! -s "$tmp_dir/names" ]; then
  fail 'OPTIONAL_BUNDLES is empty'
fi

body="$(declaration_body PROFILE_TEMPLATES '^}')" ||
  fail 'PROFILE_TEMPLATES is missing or unterminated'
printf '%s\n' "$body" | { grep -oE "[\"']@deepseek-ai/[^\"']*[\"']" || true; } |
  tr -d "\"'" | sort -u > "$tmp_dir/templates"
if [ ! -s "$tmp_dir/templates" ]; then
  fail 'PROFILE_TEMPLATES is empty or unparsable'
fi

# Dependencies resolve through the full map, which includes non-bundle clients.
declare -A package_dirs=()
declare -A bundle_packages=()
while IFS= read -r manifest; do
  name="$(jq -r '.name // empty' "$manifest")"
  [ -n "$name" ] || continue
  dir="${manifest%/package.json}"
  package_dirs["$name"]="$dir"
  if jq -e '.dsh.bundle.patch' "$manifest" >/dev/null 2>&1; then
    bundle_packages["$name"]="$dir"
  fi
done < <(find "$src/packages" -mindepth 3 -maxdepth 3 -name package.json)

requires_web() {
  local manifest="$1" dependency dependency_dir
  if [ "$(jq -r '.dsh.client.platform // empty' "$manifest")" = web ]; then
    return 0
  fi
  while IFS= read -r dependency; do
    [ -n "$dependency" ] || continue
    dependency_dir="${package_dirs[$dependency]:-}"
    [ -n "$dependency_dir" ] || continue
    if [ "$(jq -r '.dsh.client.platform // empty' "$dependency_dir/package.json")" = web ]; then
      return 0
    fi
  done < <(jq -r '(.dependencies // {}) | keys[]' "$manifest")
  return 1
}

: > "$tmp_dir/entries"
while IFS= read -r package_name; do
  dir="${bundle_packages[$package_name]:-}"
  [ -n "$dir" ] || fail "$package_name is not a workspace bundle"
  if ! jq -e --arg name "$package_name" '.dependencies | has($name)' "$cli_manifest" >/dev/null; then
    fail "$package_name is not an installation dependency"
  fi
  if grep -qxF "$package_name" "$tmp_dir/templates"; then
    fail "$package_name is selected by a shipped profile template"
  fi

  pname="${package_name##*/}"
  attr="${pname#dsh-}"
  if [ -e "$repo_root/pkgs/bundles/$attr" ]; then
    fail "generated bundle $attr collides with pkgs/bundles/$attr"
  fi

  description="$(jq -r '.meta.description // empty' "$dir/locale/en.json" 2>/dev/null || true)"
  description_zh="$(jq -r '.meta.description // empty' "$dir/locale/zh.json" 2>/dev/null || true)"
  if [ -z "$description" ]; then
    description="$(jq -r '.description // empty' "$dir/package.json")"
  fi
  [ -n "$description" ] || fail "$package_name has no description"
  if [ -z "$description_zh" ]; then
    printf 'generate-optional-bundles: %s has no Chinese description; using English\n' \
      "$package_name" >&2
    description_zh="$description"
  fi

  requires_web_value=false
  if requires_web "$dir/package.json"; then
    requires_web_value=true
  fi

  jq -n \
    --arg name "$package_name" \
    --arg attr "$attr" \
    --arg pname "$pname" \
    --arg description "$description" \
    --arg descriptionZh "$description_zh" \
    --argjson requiresWeb "$requires_web_value" \
    '{ key: $name, value: {
        attr: $attr,
        pname: $pname,
        description: $description,
        descriptionZh: $descriptionZh,
        requiresWeb: $requiresWeb,
      } }' >> "$tmp_dir/entries"
done < "$tmp_dir/names"

jq -s 'from_entries' "$tmp_dir/entries" > "$tmp_dir/optional-bundles.json"
members="$(wc -l < "$tmp_dir/names" | tr -d ' ')"

if [ -f "$dest" ] && cmp -s "$tmp_dir/optional-bundles.json" "$dest"; then
  printf 'optional bundles: %s members, unchanged\n' "$members"
  exit 0
fi

mkdir -p "$(dirname "$dest")"
mv "$tmp_dir/optional-bundles.json" "$dest"
printf 'optional bundles: %s members written to %s\n' "$members" "$dest"
