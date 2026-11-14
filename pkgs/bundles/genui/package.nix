{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-genui";
  inherit (dshSources."bundles.genui") version src;
  deployPackage = "@changfenhuang/dsh-genui";
  installation = dsh-runtime;

  pnpmDepsHash = dshSources."bundles.genui".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  dontNpmBuild = true;

  preDeploy = ''
    pnpm --filter ${lib.escapeShellArg "@changfenhuang/dsh-genui"} build
  '';

  passthru.requiresWeb = true;

  meta = {
    description = "Interactive UI components rendered inline in DSH replies via the dsh-ui fence: layouts, charts, forms, quizzes, mermaid, 3D scenes, and an action event loop";
    descriptions.zh-CN = "通过 dsh-ui fence 在 DSH 回复中内联渲染交互式 UI 组件：布局、图表、表单、测验、Mermaid 与 3D 场景，并支持动作事件循环";
    descriptions.ja = "dsh-ui フェンスを介して DSH の返信内に対話型 UI コンポーネントをインライン描画。レイアウト、グラフ、フォーム、クイズ、Mermaid、3D シーン、アクションイベントループに対応";
    homepage = "https://github.com/omdsh-dev/dsh-genui";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
