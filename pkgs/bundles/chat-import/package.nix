{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-chat-import";
  version = "0.26.4";

  src = fetchFromGitHub {
    owner = "Nwflower";
    repo = "dsh-chat-import";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mS15LdsShVlRWvqEVzJ+bNHqfhnshA+NESGSgBbRNis=";
  };

  npmDepsHash = "sha256-gSyJeJEvTxQq94DKOgF6Fyr0O0srA381zBzRv2uBs3g=";
  installation = dsh-runtime;

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Import external agent chat histories as resumable DeepSeek Harness sessions";
    descriptions.zh-CN = "将外部 Agent 聊天历史导入为可继续的 DeepSeek Harness 会话";
    descriptions.ja = "外部エージェントのチャット履歴を、再開可能な DeepSeek Harness セッションとしてインポート";
    homepage = "https://github.com/Nwflower/dsh-chat-import";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
