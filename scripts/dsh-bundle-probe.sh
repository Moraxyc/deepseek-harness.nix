#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl gnugrep gnused jq nix util-linux
# shellcheck shell=bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: dsh-bundle-probe.sh [--all] [BUNDLE...]

Boots each bundle in its own managed profile with an isolated HOME. TUI bundles
open the chat screen, plain bundles run a one-shot task up to the provider
request, and web bundles serve the web endpoint. Reports:
  ok         dsh mounts it and its rows without diagnostics
  gate-only  dsh rejects it only for unmet dsh requirements, and it boots once
             the profile exempts that exact version
  broken     it fails to boot or reports other diagnostics

The profile check is disabled for these builds; this script performs it.
TUI profiles run with a synthetic DEEPSEEK_API_KEY and an unreachable base URL.
EOF
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
system="$(nix eval --raw --impure --expr builtins.currentSystem)"

attrs=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      mapfile -t -O "${#attrs[@]}" attrs < <(
        nix eval --json ".#legacyPackages.$system.ciPackageAttrs.bundles" | jq -r 'keys[]'
      )
      ;;
    -h | --help | -*) usage ;;
    *) attrs+=("$1") ;;
  esac
  shift
done
[ "${#attrs[@]}" -gt 0 ] || usage

: "${DSH_PROBE_TIMEOUT:=20}"
results="${XDG_CACHE_HOME:-$HOME/.cache}/dsh-bundle-probe/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$results"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

log() {
  printf 'dsh-bundle-probe: %s\n' "$*" >&2
}

cat >"$work/probe.nix" <<EOF
let
  flake = builtins.getFlake "git+file://$repo_root";
  dsh = flake.packages.$system.dsh;
  bundles = flake.legacyPackages.$system.bundles;
  compose =
    attr:
    let
      bundle = bundles.\${attr};
      composition = (dsh.withProfiles { probe.bundles = [ bundle ]; }).override {
        defaultProfile = "nix-probe";
      };
    in
    (composition.overrideAttrs { dontDshBundleCheck = true; })
    // {
      probeMode =
        if bundle.passthru.requiresTui or false || bundle.passthru.requiresTty or false then
          "tty"
        else if bundle.passthru.requiresWeb or false then
          "web"
        else
          "plain";
    };
in
builtins.listToAttrs (map (attr: { name = attr; value = compose attr; }) [ $(printf '"%s" ' "${attrs[@]}")])
EOF

log "building ${#attrs[@]} compositions"
nix build --impure --no-link --keep-going -L --file "$work/probe.nix" "${attrs[@]}" \
  >"$results/build.log" 2>&1 || log "some compositions failed to build; see $results/build.log"

run_profile() {
  local out=$1 mode=$2 home=$3 logFile=$4
  local status=0
  mkdir -p "$home"
  local -a env=(
    HOME="$home"
    DSH_HOME="$home/dsh"
    DSH_TELEMETRY_DISABLED=1
    # Synthetic values; no request reaches a provider.
    DEEPSEEK_API_KEY=sk-dsh-bundle-probe
    DEEPSEEK_BASE_URL=http://127.0.0.1:9
  )
  case "$mode" in
    tty)
      # Escape dismisses first-run onboarding so the agent is created.
      { sleep 8; printf '\033'; sleep "$DSH_PROBE_TIMEOUT"; } |
        env "${env[@]}" timeout $((DSH_PROBE_TIMEOUT + 15)) script -qfc \
          "timeout --signal=INT --kill-after=2s $DSH_PROBE_TIMEOUT $(printf '%q' "$out/bin/dsh") --profile nix-probe" \
          "$logFile" >/dev/null 2>&1 || status=$?
      ;;
    web)
      env "${env[@]}" timeout --signal=TERM --kill-after=2s "$DSH_PROBE_TIMEOUT" \
        "$out/bin/dsh" --profile nix-probe --no-open --port 0 >"$logFile" 2>&1 &
      local pid=$! url='' ready=0
      while kill -0 "$pid" 2>/dev/null; do
        url="$(sed -n 's/.*dsh web: \([^ ]*\).*/\1/p' "$logFile" | head -n1)"
        if [ -n "$url" ] && curl -fs -o /dev/null --noproxy '*' --max-time 1 "$url"; then
          ready=1
          kill "$pid" 2>/dev/null || true
          break
        fi
        sleep 0.2
      done
      wait "$pid" || status=$?
      if [ "$ready" -eq 1 ]; then
        status=0
      else
        echo "dsh-bundle-probe: web endpoint never became ready" >>"$logFile"
        [ "$status" -ne 0 ] || status=1
      fi
      ;;
    plain)
      # A one-shot task creates the agent; the request then fails at the
      # unreachable provider, which is the expected end of the boot.
      env "${env[@]}" timeout "$DSH_PROBE_TIMEOUT" "$out/bin/dsh" --profile nix-probe probe \
        >"$logFile" 2>&1 || status=$?
      if [ "$status" -eq 1 ] && grep -q 'TRANSPORT' "$logFile"; then status=0; fi
      ;;
  esac
  # A live interactive session at the deadline counts as a boot.
  if [ "$mode" = tty ] && [ "$status" -eq 124 ]; then status=0; fi
  echo "$status"
}

diagnostics() {
  sed 's/\x1b\[[0-9;?<>=]*[a-zA-Z]//g; s/\x1b[()][AB0]//g; s/\x1b\][^\x07]*\x07//g' "$1" |
    tr '\r' '\n' |
    grep -E 'skipping profile bundle|disabling profile plugin|startup failed|never started|web endpoint never' |
    sort -u || true
}

# Exact name@version keys dsh rejected for unmet dsh requirements.
rejected_versions() {
  grep -oE 'Plugin [^ ]+@[^ ]+ is incompatible with dsh [^:]+' "$1" |
    sed -E 's/^Plugin (.+) is incompatible with dsh (.+)$/\1\t\2/' |
    sort -u || true
}

printf '| bundle | result | detail |\n| --- | --- | --- |\n' >"$results/summary.md"
for attr in "${attrs[@]}"; do
  out="$(nix eval --impure --raw --file "$work/probe.nix" "$attr.outPath" 2>/dev/null || true)"
  if [ -z "$out" ] || [ ! -x "$out/bin/dsh" ]; then
    printf '| %s | broken | composition does not build |\n' "$attr" >>"$results/summary.md"
    continue
  fi
  mode="$(nix eval --impure --raw --file "$work/probe.nix" "$attr.probeMode")"
  log "probing $attr ($mode)"
  home="$work/$attr"
  status="$(run_profile "$out" "$mode" "$home" "$results/$attr.log")"
  found="$(diagnostics "$results/$attr.log")"
  if [ "$status" -eq 0 ] && [ -z "$found" ]; then
    printf '| %s | ok | |\n' "$attr" >>"$results/summary.md"
    continue
  fi

  rejected="$(rejected_versions "$results/$attr.log")"
  if [ -n "$rejected" ]; then
    printf '%s\n' "$rejected" |
      jq -Rn '[inputs | split("\t") | {key: .[0], value: [.[1]]}] | from_entries' \
        >"$home/dsh/profiles/nix-probe/compatibility.json"
    status="$(run_profile "$out" "$mode" "$home" "$results/$attr.exempt.log")"
    found_exempt="$(diagnostics "$results/$attr.exempt.log")"
    if [ "$status" -eq 0 ] && [ -z "$found_exempt" ]; then
      detail="$(printf '%s' "$rejected" | cut -f1 | paste -sd ' ' -)"
      printf '| %s | gate-only | %s |\n' "$attr" "$detail" >>"$results/summary.md"
      continue
    fi
    found="$found_exempt"
  fi
  detail="$(printf '%s' "$found" | cut -c1-160 | paste -sd ' ' - | sed 's/|/\\|/g')"
  [ -n "$detail" ] || detail="exit status $status"
  printf '| %s | broken | %s |\n' "$attr" "$detail" >>"$results/summary.md"
done

cat "$results/summary.md"
log "logs in $results"
