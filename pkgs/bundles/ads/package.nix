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
  version = "0.1.0";
  deployPackage = "@dsh-external/dsh-ads";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-ads";
    rev = "401819c43f12189c1ab94159011d61a484426370";
    hash = "sha256-m8qStLJ+gWpI8/2ukJHLwBPz9+bQ68DDjdzKf2v7p/Y=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-TONbkEyLyMVzFPBeVrwyPAPza9Pnw5OOIjmu0Fi6TP0=";
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
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "DSH ad-infestation plugin with local portal ads and scam-ad parodies";
    descriptions.zh-CN = "DSH 广告插件，包含本地门户广告与诈骗广告仿制内容";
    homepage = "https://github.com/omdsh-dev/dsh-ads";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
