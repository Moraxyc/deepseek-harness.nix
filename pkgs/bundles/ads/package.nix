{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
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

  pnpmDepsHash = "sha256-+jPabCkXJJET99D/WBr34fMVaxwQbudGRA/AjSokAWk=";

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
    description = "DSH ad-infestation plugin with local portal ads and scam-ad parodies";
    descriptions.zh-CN = "DSH 广告插件，包含本地门户广告与诈骗广告仿制内容";
    homepage = "https://github.com/Nagi-ovo/dsh-ads";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
