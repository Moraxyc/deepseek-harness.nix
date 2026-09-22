{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-genui";
  version = "0.11.1-preview.2-unstable-2026-09-22";
  deployPackage = "@changfenhuang/dsh-genui";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-genui";
    rev = "05aa8226409f6e9a585b2cb3a1ce57175a7331d7";
    hash = "sha256-XUYZe34H1h5OlD2OENoM9Nkddmkr1S0rc5VwItCSEJU=";
  };

  pnpmDepsHash = "sha256-lSEwqBCB0x7Hyoqz4HIzprJniO9rGUJum8VzpYkpfOo=";

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
    homepage = "https://github.com/omdsh-dev/dsh-genui";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
