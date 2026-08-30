#!/usr/bin/env bash

dshBundleCheckHook() {
  runHook preDshBundleCheck
  echo Executing dshBundleCheckPhase

  local cmdProgram="${dshBundleCheckProgram-}"
  if [[ -z "$cmdProgram" ]]; then
    if [[ -n "${outputBin-}" ]]; then
      cmdProgram="${!outputBin}/bin/dsh"
    else
      # shellcheck disable=SC2154
      cmdProgram="$out/bin/dsh"
    fi
  fi
  [[ -x "$cmdProgram" ]] || {
    echo "dshBundleCheckHook: $cmdProgram was not found, or is not executable" >&2
    return 2
  }

  : "${dshBundleCheckHome:=$TMPDIR/dsh-bundle-check}"
  : "${dshBundleCheckTimeout:=60}"
  : "${dshBundleCheckTtyTimeout:=15}"
  : "${dshBundleCheckArgs:=--help}"
  : "${dshBundleCheckWebArgs:=--no-open --port 0}"
  mkdir -p "$dshBundleCheckHome"

  local -a profiles=()
  if [[ -n "${dshBundleCheckProfile-}" ]]; then
    profiles+=("$dshBundleCheckProfile")
  elif [[ -n "${dshBundleCheckProfiles-}" ]]; then
    read -r -a profiles <<< "$dshBundleCheckProfiles"
  else
    DSH_HOME="$dshBundleCheckHome" "$cmdProgram" --version >/dev/null 2>&1 || true
    local profileDir profileName
    for profileDir in "$dshBundleCheckHome"/profiles/*; do
      [ -d "$profileDir" ] || continue
      profileName="${profileDir##*/}"
      case "$profileName" in
        node_modules | '.' | '..')
          continue
          ;;
      esac
      profiles+=("$profileName")
    done
  fi

  if [[ "${#profiles[@]}" -eq 0 ]]; then
    echo "dshBundleCheckHook: no dsh profiles to check; skipping"
    runHook postDshBundleCheck
    return 0
  fi

  local -a checkArgs=()
  if [[ -n "$dshBundleCheckArgs" ]]; then
    read -r -a checkArgs <<< "$dshBundleCheckArgs"
  fi

  local -a webCheckArgs=()
  if [[ -n "$dshBundleCheckWebArgs" ]]; then
    read -r -a webCheckArgs <<< "$dshBundleCheckWebArgs"
  fi

  local -a webProfiles=()
  if [[ -n "${dshBundleCheckWebProfiles-}" ]]; then
    read -r -a webProfiles <<< "$dshBundleCheckWebProfiles"
  fi

  local -a ttyProfiles=()
  if [[ -n "${dshBundleCheckTtyProfiles-}" ]]; then
    read -r -a ttyProfiles <<< "$dshBundleCheckTtyProfiles"
  fi

  is_tty_profile() {
    local profile=$1 item
    for item in "${ttyProfiles[@]}"; do
      [[ "$item" == "$profile" ]] && return 0
    done
    return 1
  }

  is_web_profile() {
    local profile=$1 item
    for item in "${webProfiles[@]}"; do
      [[ "$item" == "$profile" ]] && return 0
    done
    return 1
  }

  check_web_profile() {
    local profile=$1
    local logFile="$dshBundleCheckHome/$profile.web.log"
    local line webPid webUrl=''
    local ready='' status=0

    : >"$logFile"
    DSH_HOME="$dshBundleCheckHome" DSH_TELEMETRY_DISABLED=1 \
      timeout --signal=TERM --kill-after=2s "$dshBundleCheckTimeout" \
      "$cmdProgram" --profile "$profile" "${webCheckArgs[@]}" \
      >"$logFile" 2>&1 &
    webPid=$!

    while kill -0 "$webPid" 2>/dev/null; do
      while IFS= read -r line; do
        case "$line" in
          *"dsh web: "*) read -r webUrl _ <<<"${line#*dsh web: }" ;;
        esac
      done <"$logFile"

      if [[ -n "$webUrl" ]] \
        && curl --fail --silent --output /dev/null \
          --noproxy '*' --proto '=http,https' \
          --connect-timeout 1 --max-time 1 "$webUrl"; then
        ready=1
        break
      fi
      sleep 0.1
    done

    if [[ -n "$ready" ]]; then
      kill "$webPid" 2>/dev/null || true
      wait "$webPid" 2>/dev/null || true
      cat "$logFile"
      return 0
    fi

    wait "$webPid" || status=$?
    cat "$logFile" >&2
    if [[ "$status" -eq 124 ]]; then
      echo "dshBundleCheckHook: web endpoint for $profile was not ready within $dshBundleCheckTimeout seconds" >&2
    else
      echo "dshBundleCheckHook: $profile exited before its web endpoint was ready (status $status)" >&2
    fi
    return 1
  }

  local profile
  for profile in "${profiles[@]}"; do
    echo "dshBundleCheckHook: checking dsh profile $profile"
    if is_web_profile "$profile"; then
      if ! check_web_profile "$profile"; then
        echo "dshBundleCheckHook: dsh profile $profile failed" >&2
        return 1
      fi
    elif is_tty_profile "$profile"; then
      local logFile="$dshBundleCheckHome/$profile.log"
      local wrappedCommand
      local status=0
      printf -v wrappedCommand '%q ' "$cmdProgram" --profile "$profile" "${checkArgs[@]}"
      DSH_HOME="$dshBundleCheckHome" DSH_TELEMETRY_DISABLED=1 \
        timeout "$dshBundleCheckTimeout" script -qefc \
        "timeout --signal=INT --kill-after=2s ${dshBundleCheckTtyTimeout} ${wrappedCommand}" \
        "$logFile" >/dev/null 2>&1 || status=$?
      # Interactive profiles legitimately stay alive; a timeout means they
      # booted and remained available through the smoke window.
      if [[ "$status" -ne 0 && "$status" -ne 124 ]]; then
        cat "$logFile" >&2
        echo "dshBundleCheckHook: dsh profile $profile failed" >&2
        return 1
      fi
    elif ! DSH_HOME="$dshBundleCheckHome" DSH_TELEMETRY_DISABLED=1 \
      timeout "$dshBundleCheckTimeout" \
      "$cmdProgram" --profile "$profile" "${checkArgs[@]}"; then
      echo "dshBundleCheckHook: dsh profile $profile failed" >&2
      return 1
    fi
  done

  runHook postDshBundleCheck
  echo Finished dshBundleCheckPhase
}

if [[ -z "${dontDshBundleCheck-}" ]]; then
  echo "Using dshBundleCheckHook"
  preInstallCheckHooks+=(dshBundleCheckHook)
fi
