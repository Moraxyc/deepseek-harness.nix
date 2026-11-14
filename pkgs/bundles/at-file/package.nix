{
  lib,
  dshSources,
  buildDshBundle,
  copyTree,
  dshCohort,
  dsh-runtime,
  dsh-workspace,
  pnpmConfigHook,
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
  inherit (dshSources."bundles.at-file") version src;
  deployPackage = "dsh-at-file";
  installation = dsh-runtime;

  pnpmDepsHash = dshSources."bundles.at-file".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  patches = [
    ./alpha2-compat.patch
    ./invariant-compat.patch
  ];

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    ${copyTree.followLinks {
      src = "${dsh-workspace.runtime}/node_modules/@deepseek-ai";
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

  meta = {
    description = "Codex-style @path references for the DeepSeek Harness web GUI";
    descriptions.zh-CN = "为 DeepSeek Harness 网页界面提供 Codex 风格 @路径引用";
    descriptions.ja = "DeepSeek Harness Web GUI に Codex 風の @パス参照を提供";
    homepage = "https://github.com/omdsh-dev/dsh-at-file";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
