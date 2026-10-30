#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils jq nix nodejs-slim yq-go
# shellcheck shell=bash
# shellcheck disable=SC2016
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: dsh-bump-report.sh [--json] [--strict] [--no-bundles] [--fetch-sources]
                          [--old SRC] [--kernel INSTALLABLE] NEW

NEW and SRC are an upstream version (0.2.2-alpha.3), a tag (dsh-v0.2.2-alpha.3),
or a source directory. SRC defaults to the pinned dsh-workspace source.
Bundle compatibility is evaluated with dsh-app-boot from INSTALLABLE
(default .#dsh-kernel) against built bundles, or their sources when present in
the store. --fetch-sources downloads the missing sources first. --strict exits
nonzero when the report lists actions.
EOF
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
system="$(nix eval --raw --impure --expr builtins.currentSystem)"

report_args=()
old=''
new=''
kernel_installable='.#dsh-kernel'
bundles=1
fetch_sources=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json | --strict) report_args+=("$1") ;;
    --no-bundles) bundles=0 ;;
    --fetch-sources) fetch_sources=1 ;;
    --old)
      [ "$#" -ge 2 ] || usage
      old=$2
      shift
      ;;
    --kernel)
      [ "$#" -ge 2 ] || usage
      kernel_installable=$2
      shift
      ;;
    -h | --help) usage ;;
    -*) usage ;;
    *)
      [ -z "$new" ] || usage
      new=$1
      ;;
  esac
  shift
done
[ -n "$new" ] || usage

resolve_source() {
  local ref=$1
  if [ -d "$ref" ]; then
    realpath "$ref"
    return
  fi
  case "$ref" in
    dsh-v*) ;;
    *) ref="dsh-v$ref" ;;
  esac
  nix flake prefetch --json "github:deepseek-ai/deepseek-harness/$ref" | jq -er .storePath
}

log() {
  printf 'dsh-bump-report: %s\n' "$*" >&2
}

log "resolving upstream sources"
if [ -n "$old" ]; then
  old_src="$(resolve_source "$old")"
else
  old_src="$(nix build --no-link --print-out-paths ".#dsh-workspace.src")"
fi
new_src="$(resolve_source "$new")"
log "old $old_src"
log "new $new_src"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [ "$bundles" -eq 1 ]; then
  log "resolving the kernel"
  kernel="$(nix build --no-link --print-out-paths "$kernel_installable")"
  log "evaluating bundles"
  report_args+=(--app-boot "$kernel/lib/deepseek-harness/node_modules/@deepseek-ai/dsh-app-boot")

  # The CI bundle set: buildable on this platform, not removed or broken.
  nix eval --json ".#legacyPackages.$system" --apply '
    packages:
    map (
      attr:
      let
        bundle = packages.bundles.${attr};
        src = bundle.src or null;
      in
      {
        inherit attr;
        version = bundle.version or "";
        out = bundle.outPath;
        src = if src == null then null else src.outPath;
        srcDrv = if src == null then null else src.drvPath;
        dshEngines = bundle.passthru.dshEngines or null;
        workspace = (src.pname or null) == "dsh-workspace";
      }
    ) (builtins.attrNames packages.ciPackageAttrs.bundles)
  ' >"$tmp_dir/bundles.json"

  # Bundles without a local build fall back to their source.
  mapfile -t missing_srcs < <(
    jq -r '.[] | select(.workspace | not) | select(.srcDrv != null) | [.out, .src, .srcDrv] | @tsv' \
      "$tmp_dir/bundles.json" |
      while IFS=$'\t' read -r out src drv; do
        [ -e "$out" ] || [ -e "$src" ] || printf '%s^out\n' "$drv"
      done
  )
  if [ "${#missing_srcs[@]}" -gt 0 ]; then
    if [ "$fetch_sources" -eq 1 ]; then
      log "fetching ${#missing_srcs[@]} bundle sources"
      nix build --no-link -L "${missing_srcs[@]}"
    else
      log "${#missing_srcs[@]} bundles are neither built nor fetched; pass --fetch-sources to include them"
    fi
  fi
  jq -c '.[]' "$tmp_dir/bundles.json" | while IFS= read -r entry; do
    out="$(jq -r .out <<<"$entry")"
    src="$(jq -r '.src // ""' <<<"$entry")"
    out_exists=false
    src_exists=false
    [ -e "$out" ] && out_exists=true
    [ -n "$src" ] && [ -e "$src" ] && src_exists=true
    jq -c --argjson outExists "$out_exists" --argjson srcExists "$src_exists" \
      '.outExists = $outExists | if $srcExists then . else .src = null end' <<<"$entry"
  done | jq -s . >"$tmp_dir/bundles.tmp"
  report_args+=(--bundles "$tmp_dir/bundles.tmp")
  log "writing the report"
fi

node "$repo_root/scripts/dsh-bump-report.mjs" \
  --old "$old_src" \
  --new "$new_src" \
  --repo "$repo_root" \
  "${report_args[@]}"
