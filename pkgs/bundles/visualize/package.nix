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
  version = "0-unstable-2026-08-17";
  deployPackage = "@dsh-external/dsh-visualize";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-visualize";
    rev = "dd41b388db67f146c928772c6242c0acdb5bbeae";
    hash = "sha256-VFJQYE2YFTL1NuQL7rMByM3AmvSas9AR0sTgOI3tabQ=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-qof8bKOw/YO32svWuSP5RHfqttfWRXQyqCUxLmwQZAw=";
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
