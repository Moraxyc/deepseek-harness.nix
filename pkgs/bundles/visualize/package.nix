{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-visualize";
  version = "0-unstable-2026-08-27";
  deployPackage = "@dsh-external/dsh-visualize";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-visualize";
    rev = "9667c0e9cf0ea463b9b45b2845de62da34fd918a";
    hash = "sha256-AKNWKio3DTvrI8OcMHu1DkTvmEDcjT1xZYhWic6PVRE=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-I6NFypU/IfZ9ZWPxjP/rjh7qaXpKjfAaA/WnGFZ7xpo=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postDeploy = ''
    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    for entry in "$out"/lib/*; do
      case "$(basename "$entry")" in
        node_modules)
          continue
          ;;
      esac
      mv "$entry" "$deployPackagePath/"
    done
  '';

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
