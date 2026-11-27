# shellcheck shell=bash
# Fetchrix prepare hook for dsh-workspace, run in the upstream source tree.
# Packaged by scripts/default.nix.

mkdir -p .fetchrix
commit="$(timeout 60 git ls-remote https://github.com/deepseek-ai/deepseek-harness.git \
  "refs/tags/dsh-v${FETCHRIX_VERSION:?}" "refs/tags/dsh-v$FETCHRIX_VERSION^{}" | tail -n1 | cut -f1)"
if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'fetchrix-prepare-dsh-workspace: could not resolve the commit of dsh-v%s\n' "$FETCHRIX_VERSION" >&2
  exit 1
fi
jq -n --arg commit "$commit" '$commit' > .fetchrix/client-commit.json
generate-optional-bundles "$PWD" "$PWD/.fetchrix/optional-bundles.json"
yq -o=json pnpm-lock.yaml | jq '{
  "claude-agent-sdk": (
    .importers."packages/subagent/subagent-claude-code".dependencies."@anthropic-ai/claude-agent-sdk".version as $v |
    .snapshots["@anthropic-ai/claude-agent-sdk@\($v)"].optionalDependencies // {} | keys
  ),
  "codex": (
    .importers."packages/subagent/subagent-codex".dependencies."@openai/codex".version as $v |
    .snapshots["@openai/codex@\($v)"].optionalDependencies // {} | keys
  )
}' > .fetchrix/subagent-platforms.json
