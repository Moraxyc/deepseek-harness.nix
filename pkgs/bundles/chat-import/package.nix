{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-chat-import";
  inherit (dshSources."bundles.chat-import") version src;

  npmDepsHash = dshSources."bundles.chat-import".npmDepsHash;
  installation = dsh-runtime;

  passthru.requiresWeb = true;

  meta = {
    description = "Import external agent chat histories as resumable DeepSeek Harness sessions";
    descriptions.zh-CN = "将外部 Agent 聊天历史导入为可继续的 DeepSeek Harness 会话";
    descriptions.ja = "外部エージェントのチャット履歴を、再開可能な DeepSeek Harness セッションとしてインポート";
    homepage = "https://github.com/Nwflower/dsh-chat-import";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
