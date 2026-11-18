# shellcheck shell=bash
# Packaged by scripts/default.nix; run with `nix run .#tools.dsh-bundle-probe`.

usage() {
  cat >&2 <<'EOF'
usage: dsh-bundle-probe [--all] [BUNDLE...]

Boots each bundle in its own managed profile (legacyPackages.bundleProbes)
with an isolated HOME. TUI bundles open the chat screen, plain and tty bundles
run a one-shot task up to the provider request, and web and ACP bundles serve
their endpoint. Reports:
  ok         dsh mounts it and its rows without diagnostics
  gate-only  dsh rejects it only for unmet dsh requirements, and it boots once
             the profile exempts that exact version
  broken     it fails to boot or reports other diagnostics

Run it from the repository; the working tree is copied to the store once at
startup. Profiles run with a synthetic DEEPSEEK_API_KEY and an unreachable
base URL. DSH_PROBE_TIMEOUT sets the boot timeout in seconds (default 20).
EOF
  exit 2
}

log() {
  printf 'dsh-bundle-probe: %s\n' "$*" >&2
}

all=0
attrs=()
for arg in "$@"; do
  case "$arg" in
    --all) all=1 ;;
    -*) usage ;;
    *) attrs+=("$arg") ;;
  esac
done

repo_root=$(git rev-parse --show-toplevel)
system=$(nix eval --raw --impure --expr builtins.currentSystem)
flake="path:$(nix flake archive --json --no-write-lock-file "git+file://$repo_root" | jq -er .path)"
probes="$flake#legacyPackages.$system.bundleProbes"

modes=$(nix eval --json "$probes" --apply 'builtins.mapAttrs (_: p: p.passthru.bundleCheckProfiles.modes.nix-test)')
if [ "$all" -eq 1 ]; then
  mapfile -t -O "${#attrs[@]}" attrs < <(jq -r 'keys[]' <<<"$modes")
fi
[ "${#attrs[@]}" -gt 0 ] || usage

: "${DSH_PROBE_TIMEOUT:=20}"
results="${XDG_CACHE_HOME:-$HOME/.cache}/dsh-bundle-probe/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$results"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

log "building ${#attrs[@]} compositions"
nix build --no-link --keep-going -L "${attrs[@]/#/$probes.}" >"$results/build.log" 2>&1 ||
  log "some compositions failed to build; see $results/build.log"

# Boots the composition at OUT in MODE; writes the dsh output to LOG and the
# smoke result to LOG.smoke.
probe() {
  local out=$1 mode=$2 home=$3 logFile=$4
  local -a options=(--log "$logFile" --timeout "$DSH_PROBE_TIMEOUT") args=()
  case "$mode" in
    tui)
      options+=(--dismiss-onboarding)
      mode="tty"
      ;;
    plain | tty)
      # A one-shot task creates the agent; the request then fails at the
      # unreachable provider, which is the expected end of the boot.
      options+=(--until-provider)
      args=(-- probe)
      ;;
  esac
  mkdir -p "$home"
  HOME="$home" DSH_HOME="$home/dsh" \
    DEEPSEEK_API_KEY=sk-dsh-bundle-probe DEEPSEEK_BASE_URL=http://127.0.0.1:9 \
    dsh-profile-smoke "${options[@]}" "$out/bin/dsh" nix-test "$mode" "${args[@]}" \
    >/dev/null 2>"$logFile.smoke"
}

# Exact name@version keys dsh rejected for unmet dsh requirements.
rejected_versions() {
  grep -oE 'Plugin [^ ]+@[^ ]+ is incompatible with dsh [^:]+' "$1" |
    sed -E 's/^Plugin (.+) is incompatible with dsh (.+)$/\1\t\2/' |
    sort -u || true
}

# The dropped rows when the smoke check reports them, otherwise its reason.
detail() {
  local reason
  reason=$(tail -n1 "$1")
  case "$reason" in
    *'dropped a bundle or plugin row') head -n3 "$1" | cut -c1-160 | paste -sd ' ' - ;;
    *) printf '%s\n' "${reason#dsh-profile-smoke: nix-test: }" ;;
  esac | sed 's/|/\\|/g'
}

printf '| bundle | result | detail |\n| --- | --- | --- |\n' >"$results/summary.md"
failed=0
for attr in "${attrs[@]}"; do
  mode=$(jq -r --arg attr "$attr" '.[$attr] // empty' <<<"$modes")
  out=$(nix eval --raw "$probes.$attr.outPath" 2>/dev/null || true)
  if [ -z "$mode" ] || [ ! -x "$out/bin/dsh" ]; then
    printf '| %s | broken | composition does not build |\n' "$attr" >>"$results/summary.md"
    failed=1
    continue
  fi
  log "probing $attr ($mode)"
  home="$work/$attr"
  if probe "$out" "$mode" "$home" "$results/$attr.log"; then
    printf '| %s | ok | |\n' "$attr" >>"$results/summary.md"
    continue
  fi

  rejected=$(rejected_versions "$results/$attr.log")
  logFile="$results/$attr.log"
  if [ -n "$rejected" ]; then
    printf '%s\n' "$rejected" |
      jq -Rn '[inputs | split("\t") | {key: .[0], value: [.[1]]}] | from_entries' \
        >"$home/dsh/profiles/nix-test/compatibility.json"
    if probe "$out" "$mode" "$home" "$results/$attr.exempt.log"; then
      printf '| %s | gate-only | %s |\n' "$attr" "$(cut -f1 <<<"$rejected" | paste -sd ' ' -)" >>"$results/summary.md"
      continue
    fi
    logFile="$results/$attr.exempt.log"
  fi
  printf '| %s | broken | %s |\n' "$attr" "$(detail "$logFile.smoke")" >>"$results/summary.md"
  failed=1
done

cat "$results/summary.md"
log "logs in $results"
exit "$failed"
