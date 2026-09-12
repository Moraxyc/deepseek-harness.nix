{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-mnemon";
  version = "0.5.8";
  deployPackage = "dsh-mnemon";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-mnemon";
    tag = "v${finalAttrs.version}";
    hash = "sha256-IoBu4SG/i/syZeeC42uUCaSU5MsGP8w2TH9mkp/BBMM=";
  };

  pnpmDepsHash = "sha256-E0QG18/fwnbvSw/sgS1i1OHRKiX6xUCReZdhcvcSnHs=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  linkKernelNodeModules = dsh-kernel;

  # The root build does not build the source-only plugin workspaces, while
  # deploy intentionally skips dependency lifecycle scripts.
  preDeploy = ''
    pnpm --workspace-concurrency=4 --config.ignore-workspace-cycles=true -r build
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Composable three-tier memory control plane for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的可组合三层记忆控制平面";
    homepage = "https://github.com/omdsh-dev/dsh-mnemon";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
