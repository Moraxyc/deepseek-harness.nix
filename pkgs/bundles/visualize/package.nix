{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-visualize";
  version = "0.1.7-unstable-2026-10-18";
  deployPackage = "@nagi-ovo/dsh-visualize";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-visualize";
    rev = "1ab0d903b4d689524e9f72e5a4624e93d0b47cd2";
    hash = "sha256-xXHYUf5WZ2NRbCNcr4tx9u22BUmXWhkG0U9EE7bev1c=";
  };

  pnpmDepsHash = "sha256-0Y4KiZrZM8cpYX7jlfdc6HccuAeT0u00cJOq5sMmqpE=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "DSH inline visualization plugin: render interactive HTML fragments as sandboxed cards";
    descriptions.zh-CN = "DSH 对话内可视化插件：模型调用 visualize 后，在 Web UI 中渲染可交互的沙箱卡片";
    homepage = "https://github.com/Nagi-ovo/dsh-visualize";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
