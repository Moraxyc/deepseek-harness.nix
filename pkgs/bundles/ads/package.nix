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
  pname = "dsh-ads";
  version = "0-unstable-2026-08-18";
  deployPackage = "@dsh-external/dsh-ads";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-ads";
    rev = "3a2ba704bc383099c686d3288ff6e0d61fc391e5";
    hash = "sha256-ixRxETpVrot/mqtnzytpKFxk/QnouPL3dVXoNjpBb1o=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-w8IInG5knJJ85etVZd0f2Prr9wSyltlfMoia3yeAA/Y=";
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
    description = "DSH ad-infestation plugin with local portal ads and scam-ad parodies";
    descriptions.zh-CN = "DSH 广告插件，包含本地门户广告与诈骗广告仿制内容";
    homepage = "https://github.com/Nagi-ovo/dsh-ads";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
