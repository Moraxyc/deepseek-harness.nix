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
  version = "0.14.0-unstable-2026-10-25";
  deployPackage = "@changfenhuang/dsh-genui";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-genui";
    rev = "a6ecd746586102b3496fd7230eaa4445797202b6";
    hash = "sha256-+JnQ8sdwyrDmGPEHUpSXiblC7741WO4AyOZjEAPmj0s=";
  };

  pnpmDepsHash = "sha256-J5lMa9B4wTAXFSQx8q4i57kBRp7peYrdPRe03pd62ok=";

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
