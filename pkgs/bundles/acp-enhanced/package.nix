{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-acp-enhanced";
  inherit (dshSources."bundles.acp-enhanced") version src;
  deployPackage = "dsh-acp-enhanced";

  # dsh 0.2.2-alpha.2 dropped the @deepseek-ai/dsh-tool-subagent-control/list-agents export.
  patches = [ ./0.2.2-remove-list-agents.patch ];

  pnpmDepsHash = dshSources."bundles.acp-enhanced".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  dontNpmBuild = true;
  installation = dsh-runtime;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    for testScript in \
      scripts/api-surface-check.mjs \
      scripts/boot-classify-test.mjs \
      scripts/support-claim-test.mjs \
      scripts/docs-claim-test.mjs \
      scripts/replay-order-test.mjs \
      scripts/codec-image-test.mjs \
      scripts/terminal-codec-test.mjs \
      scripts/session-facts-test.mjs \
      scripts/context-window-test.mjs \
      scripts/tool-result-test.mjs \
      scripts/cancel-cause-test.mjs \
      scripts/stored-titles-test.mjs; do
      node "$testScript"
    done
    runHook postCheck
  '';

  preDeploy = ''
    printf '\npackages:\n  - .\n' >> pnpm-workspace.yaml
  '';

  passthru.requiresAcp = true;

  meta = {
    description = "Enhanced ACP server for DeepSeek Harness with streaming, telemetry, model and reasoning-effort switching, and permission-preset control";
    descriptions.zh-CN = "DeepSeek Harness 增强版 ACP 服务器，支持流式输出、遥测统计、模型与推理强度切换及权限预设控制";
    descriptions.ja = "ストリーミング、テレメトリ、モデル・推論強度切り替え、権限プリセット制御を備えた DeepSeek Harness 向け拡張 ACP サーバー";
    homepage = "https://github.com/grunmin/dsh-acp-enhanced";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
