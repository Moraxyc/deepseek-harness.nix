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
  version = "0.1.3-unstable-2026-10-20";
  deployPackage = "@nagi-ovo/dsh-ads";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-ads";
    rev = "a5854a37bbe24078878740ae4567e59cc75c29ec";
    hash = "sha256-Owkwkm/NJN4CpohW0iNqaC+Tm2C8Fks8Z1Zh25HSWZM=";
  };

  pnpmDepsHash = "sha256-OqSxOpr6jrmIQ/t1x2+sHbAWkuzyJMofnN2AaUt4P1E=";

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
