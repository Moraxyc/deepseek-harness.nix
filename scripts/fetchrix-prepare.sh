#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# fetchrix runs hooks with the caller's PATH; take the tools from the flake inputs.
if [ -z "${FETCHRIX_PREPARE_TOOLS:-}" ]; then
  exec nix shell --inputs-from "$repo_root" \
    nixpkgs#bash \
    nixpkgs#coreutils \
    nixpkgs#diffutils \
    nixpkgs#findutils \
    nixpkgs#gawk \
    nixpkgs#gitMinimal \
    nixpkgs#gnugrep \
    nixpkgs#gnused \
    nixpkgs#jq \
    nixpkgs#yarn-berry_4.yarn-berry-fetcher \
    nixpkgs#yq-go \
    -c env FETCHRIX_PREPARE_TOOLS=1 bash "${BASH_SOURCE[0]}" "$@"
fi

name="${1:?package name required}"
cd "${FETCHRIX_SOURCE:?}"

case "$name" in
  dsh-workspace)
    mkdir -p .fetchrix
    commit="$(timeout 60 git ls-remote https://github.com/deepseek-ai/deepseek-harness.git \
      "refs/tags/dsh-v${FETCHRIX_VERSION:?}" "refs/tags/dsh-v$FETCHRIX_VERSION^{}" | tail -n1 | cut -f1)"
    if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
      printf 'fetchrix-prepare: could not resolve workspace commit\n' >&2
      exit 1
    fi
    jq -n --arg commit "$commit" '$commit' > .fetchrix/client-commit.json
    bash "$repo_root/scripts/generate-optional-bundles.sh" "$PWD" "$PWD/.fetchrix/optional-bundles.json"
    ;;
  bundles.notification)
    yq -i '
      .importers.".".devDependencies |= with_entries(
        select(.key | test("^@deepseek-ai/") | not)
      )
    ' pnpm-lock.yaml
    ;;
  bundles.subscriptions)
    yq -i '
      .importers.".".devDependencies |= with_entries(
        select(
          (.key | test("^@deepseek-ai/") | not)
          or (.key | test("@deepseek-ai/(cordis|dsh-attachment|dsh-home-paths|dsh-llm|dsh-tools|dsh-web|schemastery)"))
        )
      )
    ' pnpm-lock.yaml
    ;;
  bundles.graph-memory)
    # Reuse the recorded resolution so a version bump only completes the lock.
    if [ -f "$repo_root/_sources/bundles.graph-memory/package-lock.json" ]; then
      cp "$repo_root/_sources/bundles.graph-memory/package-lock.json" package-lock.json
    fi
    yq -i -o json '.scripts |= del(.prepare, .prepack) | .devDependencies |= del(.vitest)' package.json
    ;;
  dsh-desktop-unofficial)
    mkdir -p .fetchrix
    awk '
      /^".*@file:/ { skip = 1; next }
      skip && /^$/ { skip = 0; next }
      !skip { print }
    ' yarn.lock > .fetchrix/yarn.lock
    yarn-berry-fetcher missing-hashes .fetchrix/yarn.lock > .fetchrix/missing-hashes.json
    ;;
esac
