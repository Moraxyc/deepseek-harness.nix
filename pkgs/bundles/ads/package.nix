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
  version = "0-unstable-2026-08-27";
  deployPackage = "@dsh-external/dsh-ads";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-ads";
    rev = "8eef607d2ab15737ec93233094d77aff7e5e8da3";
    hash = "sha256-iZkC9e4hK3xivf0Xx6LjPO/17dlNpGZ25x91EjllIYs=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-+jPabCkXJJET99D/WBr34fMVaxwQbudGRA/AjSokAWk=";
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
