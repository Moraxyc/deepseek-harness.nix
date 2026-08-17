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

  local profile
  for profile in "${profiles[@]}"; do
    echo "dshBundleCheckHook: checking dsh profile $profile"
    if is_tty_profile "$profile"; then
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
