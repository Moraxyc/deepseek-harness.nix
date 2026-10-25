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
  version = "0.1.7-unstable-2026-10-24";
  deployPackage = "@nagi-ovo/dsh-visualize";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-visualize";
    rev = "cf6b3a3f5a3f02b83a380890a5b672a350715344";
    hash = "sha256-OQH6GdpEQTHIgejjTkAAjpFFmf4q1VpWsDF1K1cUDp8=";
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
