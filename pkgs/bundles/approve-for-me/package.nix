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
  pname = "dsh-approve-for-me";
  version = "0-unstable-2026-08-17";
  deployPackage = "dsh-approve-for-me";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "timeance";
    repo = "dsh-approve-for-me";
    rev = "b13c48e970ac72d4fc63e234a80980e3095d01bf";
    hash = "sha256-EH8aq24917F7MrjaVWJaPtqQALiy/8IjVqMK2IpRVpE=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-CtAdFXsdTk1pcm1BoKQ4W87yhibr2gz/N7C/HzShFto=";
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
    description = "Rule-gated automatic approval for DeepSeek Harness sandbox escalations";
    descriptions.zh-CN = "为 DeepSeek Harness 沙箱提权提供规则分流的自动审批插件";
    homepage = "https://github.com/timeance/dsh-approve-for-me";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
