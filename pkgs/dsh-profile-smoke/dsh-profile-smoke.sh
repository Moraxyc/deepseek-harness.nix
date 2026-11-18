# shellcheck shell=bash
# Packaged by package.nix next to this file.

usage() {
  cat >&2 <<'EOF'
usage: dsh-profile-smoke [OPTION...] DSH PROFILE MODE [-- ARG...]

Runs `DSH --profile PROFILE ARG...` in the inherited environment and waits
until the profile is up:
  plain  the command exits with status 0
  tty    the command runs under script(1) and exits with status 0, or is
         still running when the timeout expires
  acp    the agent answers an ACP initialize request on stdin
  web    the web endpoint printed by dsh answers over HTTP; adds
         --no-open --port 0
The check then fails if dsh skipped a profile bundle, disabled a plugin row,
or reports plugins that did not activate or never started.

  --log FILE            write the dsh output to FILE (required)
  --timeout SECONDS     time allowed for the boot (default 60)
  --allow-skip NAME     tolerate a skipped profile bundle NAME; repeatable
  --until-provider      the command stops at an unreachable model provider;
                        a TRANSPORT error then counts as a boot
  --dismiss-onboarding  in tty mode, press Escape after 8 seconds
EOF
  exit 2
}

log='' timeout=60 until_provider=0 dismiss_onboarding=0
allowed=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --log)
      log=${2-}
      shift
      ;;
    --timeout)
      timeout=${2-}
      shift
      ;;
    --allow-skip)
      allowed+=(-e "skipping profile bundle \"${2-}\":")
      shift
      ;;
    --until-provider) until_provider=1 ;;
    --dismiss-onboarding) dismiss_onboarding=1 ;;
    -*) usage ;;
    *) break ;;
  esac
  shift
done
[ "$#" -ge 3 ] && [ -n "$log" ] && [[ "$timeout" =~ ^[0-9]+$ ]] || usage
program=$1 profile=$2 mode=$3
shift 3
if [ "$#" -gt 0 ]; then
  [ "$1" = -- ] || usage
  shift
fi
command=("$program" --profile "$profile" "$@")

fail() {
  printf 'dsh-profile-smoke: %s: %s\n' "$profile" "$1" >&2
  exit 1
}

fail_boot() {
  tail -n 50 "$log" >&2
  fail "$1"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export DSH_TELEMETRY_DISABLED=1
: >"$log"
status=0

# Runs the command in the background until the READY function succeeds.
serve() {
  local ready=$1 stdin=$2 pid
  timeout --signal=TERM --kill-after=2s "$timeout" "${command[@]}" <"$stdin" >"$log" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if "$ready"; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return
    fi
    sleep 0.2
  done
  wait "$pid" || status=$?
  if [ "$status" -eq 124 ]; then
    fail_boot "$mode endpoint was not ready within $timeout seconds"
  fi
  fail_boot "exited with status $status before its $mode endpoint was ready"
}

acp_ready() {
  grep -Eq '^\{"jsonrpc":"2\.0","id":1,"result":' "$log"
}

web_ready() {
  local url
  url=$(sed -n 's/.*dsh web: \([^ ]*\).*/\1/p' "$log" | head -n1)
  [ -n "$url" ] && curl --fail --silent --output /dev/null --noproxy '*' \
    --proto '=http,https' --connect-timeout 1 --max-time 1 "$url"
}

case "$mode" in
  plain)
    timeout --kill-after=2s "$timeout" "${command[@]}" </dev/null >"$log" 2>&1 || status=$?
    ;;
  tty)
    input=/dev/null
    if [ "$dismiss_onboarding" -eq 1 ]; then
      # Escape dismisses first-run onboarding so the agent is created.
      exec 4< <(sleep 8; printf '\033'; sleep "$timeout")
      feeder=$!
      input=/dev/fd/4
    fi
    inner=(timeout --signal=INT --kill-after=2s "$timeout" "${command[@]}")
    if [ "$(uname -s)" = Darwin ]; then
      # BSD script(1) takes the command as argv and returns its exit status.
      timeout $((timeout + 15)) script -qF "$log" "${inner[@]}" <"$input" >/dev/null 2>&1 || status=$?
    else
      timeout $((timeout + 15)) script -qefc "$(printf '%q ' "${inner[@]}")" "$log" \
        <"$input" >/dev/null 2>&1 || status=$?
    fi
    if [ -n "${feeder-}" ]; then
      kill "$feeder" 2>/dev/null || true
      exec 4<&-
    fi
    ;;
  acp)
    mkfifo "$work/acp.in"
    exec 3<>"$work/acp.in"
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{},"clientInfo":{"name":"dsh-profile-smoke","version":"0.1.0"}}}' >&3
    serve acp_ready "$work/acp.in"
    exec 3>&-
    ;;
  web)
    command+=(--no-open --port 0)
    serve web_ready /dev/null
    ;;
  *) usage ;;
esac

booted=0
if [ "$status" -eq 0 ]; then
  booted=1
elif [ "$until_provider" -eq 1 ]; then
  if { [ "$status" -eq 1 ] || [ "$status" -eq 124 ]; } && grep -q 'dsh: TRANSPORT:' "$log"; then
    booted=1
  fi
elif [ "$mode" = tty ] && [ "$status" -eq 124 ]; then
  # An interactive session still running at the deadline has booted.
  booted=1
fi
[ "$booted" -eq 1 ] || fail_boot "exited with status $status"

# dsh boots without bundles or plugin rows it cannot load, so a boot alone
# does not prove they mounted.
dropped=$(
  sed 's/\x1b\[[0-9;?<>=]*[a-zA-Z]//g; s/\x1b[()][AB0]//g; s/\x1b\][^\x07]*\x07//g' "$log" |
    tr '\r' '\n' |
    grep -E 'skipping profile bundle|disabling profile plugin|did not activate|never started' |
    if [ "${#allowed[@]}" -gt 0 ]; then grep -vF "${allowed[@]}"; else cat; fi |
    sort -u
) || true
if [ -n "$dropped" ]; then
  printf '%s\n' "$dropped" >&2
  fail "dropped a bundle or plugin row"
fi
printf 'dsh-profile-smoke: %s: booted in %s mode\n' "$profile" "$mode"
