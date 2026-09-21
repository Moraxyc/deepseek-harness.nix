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
    "dsh-api-session-controller"
    "dsh-api-workspace-controller"
    "dsh-client-connection"
    "dsh-client-store"
    "dsh-client-locale"
    "dsh-client-ui-conversation"
    "dsh-client-ui-input-trigger"
    "dsh-client-ui-primitives"
    "dsh-client-ui-renderer"
    "dsh-client-ui-session"
    "dsh-client-ui-workspace"
    "dsh-client-ui-settings"
  ];
in
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-at-file";
  version = "0.7.0";
  deployPackage = "dsh-at-file";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-at-file";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JU8JH9t2+72FW4FyGsOrZebGW0tPC7VzIkZuVfhlLmE=";
  };

  pnpmDepsHash = "sha256-pTHoDj3MwGC4snJ5J8eKW0slfMdcEhvgmLgD+Kqa8eM=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  patches = [ ./alpha2-compat.patch ];

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    ${copyTree.followLinks {
      src = "${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai";
      dest = "node_modules/@deepseek-ai";
    }}

    ${dshCohort.installPackages { names = clientPackages; }}
  '';

  postBuild = ''
    for clientPackage in ${lib.concatStringsSep " " clientPackages}; do
      rm -rf "node_modules/$clientPackage"
    done
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Codex-style @path references for the DeepSeek Harness web GUI";
    descriptions.zh-CN = "为 DeepSeek Harness 网页界面提供 Codex 风格 @路径引用";
    homepage = "https://github.com/omdsh-dev/dsh-at-file";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
