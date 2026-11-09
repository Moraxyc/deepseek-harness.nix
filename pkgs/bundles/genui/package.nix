{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-genui";
  version = "0.16.0-unstable-2026-11-09";
  deployPackage = "@changfenhuang/dsh-genui";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-genui";
    rev = "8ed3999147d0d1a4815706d087a6f6e1fca9268f";
    hash = "sha256-v9JHKrGHWIw2D3wKflX5TP2kz8+DGN8Bve503vGAgOk=";
  };

  pnpmDepsHash = "sha256-0QfBbAgo2LMz/6LEqxIRnxP0+n0jz9fnvVoBRDEYJKY=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  dontNpmBuild = true;

  preDeploy = ''
    pnpm --filter ${lib.escapeShellArg "@changfenhuang/dsh-genui"} build
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Interactive UI components rendered inline in DSH replies via the dsh-ui fence: layouts, charts, forms, quizzes, mermaid, 3D scenes, and an action event loop";
    descriptions.zh-CN = "通过 dsh-ui fence 在 DSH 回复中内联渲染交互式 UI 组件：布局、图表、表单、测验、Mermaid 与 3D 场景，并支持动作事件循环";
    descriptions.ja = "dsh-ui フェンスを介して DSH の返信内に対話型 UI コンポーネントをインライン描画。レイアウト、グラフ、フォーム、クイズ、Mermaid、3D シーン、アクションイベントループに対応";
    homepage = "https://github.com/omdsh-dev/dsh-genui";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
