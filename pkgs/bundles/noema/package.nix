{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  copyTree,
  dshCohort,
  dsh-kernel,
  pnpmConfigHook,
  nix-update-script,
}:
let
  clientPackages = dshCohort.select [
    "dsh-client-ui-slots"
    "dsh-api-remotes"
    "dsh-client-connection"
    "dsh-client-locale"
    "dsh-client-ui-renderer"
    "dsh-client-ui-settings"
  ];
in
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-noema";
  version = "0.1.0-rc.4";
  deployPackage = "@zseven-w/dsh-noema";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-noema";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CuMTu7FOH77e+T6WSgFa5/1GqdYftBlI3gLzi9SUKQE=";
  };

  pnpmDepsHash = "sha256-4NAETbjerUa61o3AOUpsQGlV8bVttk31Lr8HJjslc/A=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    ${copyTree.followLinks {
      src = "${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai";
      dest = "node_modules/@deepseek-ai";
    }}
    ${dshCohort.installPackages { names = clientPackages; }}
  '';

  postNormalizeDeploy = ''
    for clientPackage in ${lib.concatStringsSep " " clientPackages}; do
      rm -rf \
        "$out/lib/node_modules/$clientPackage" \
        "$deployPackagePath/node_modules/$clientPackage"
    done
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=unstable"
    ];
  };

  meta = {
    description = "Noema long-term memory plugin for DSH with recall tools and a settings page";
    descriptions.zh-CN = "DSH 的 Noema 长期记忆插件，提供召回工具与设置页";
    homepage = "https://github.com/ZSeven-W/dsh-noema";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
