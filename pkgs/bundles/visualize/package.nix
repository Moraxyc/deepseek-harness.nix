{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-visualize";
  inherit (dshSources."bundles.visualize") version src;
  deployPackage = "@nagi-ovo/dsh-visualize";
  installation = dsh-runtime;

  pnpmDepsHash = dshSources."bundles.visualize".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  passthru.requiresWeb = true;

  meta = {
    description = "DSH inline visualization plugin: render interactive HTML fragments as sandboxed cards";
    descriptions.zh-CN = "DSH 对话内可视化插件：模型调用 visualize 后，在 Web UI 中渲染可交互的沙箱卡片";
    descriptions.ja = "DSH のインライン可視化プラグイン。モデルが visualize を呼び出すと、対話型 HTML フラグメントを Web UI 内のサンドボックス化されたカードとして描画";
    homepage = "https://github.com/Nagi-ovo/dsh-visualize";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
