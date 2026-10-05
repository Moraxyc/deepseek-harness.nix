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
  version = "0.11.3-unstable-2026-10-05";
  deployPackage = "@changfenhuang/dsh-genui";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-genui";
    rev = "0683e5f7319e871b2cd17cff339c2d952b61b7f2";
    hash = "sha256-Spmd/To0IfGgYwulYGJ4P9rJx8EhNysNa0+KrX+baxk=";
  };

  pnpmDepsHash = "sha256-cwqOi1+ukpOVBY4onl1nwYXujIsqTixuGwDYqlIxx/E=";

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
