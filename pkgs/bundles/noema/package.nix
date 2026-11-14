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
    "dsh-client-connection"
    "dsh-client-locale"
    "dsh-client-ui-renderer"
    "dsh-client-ui-settings"
  ];
in
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-noema";
  inherit (dshSources."bundles.noema") version src;
  deployPackage = "@zseven-w/dsh-noema";
  installation = dsh-runtime;

  pnpmDepsHash = dshSources."bundles.noema".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    ${copyTree.followLinks {
      src = "${dsh-workspace.runtime}/node_modules/@deepseek-ai";
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

  meta = {
    description = "Noema long-term memory plugin for DSH with recall tools and a settings page";
    descriptions.zh-CN = "DSH 的 Noema 长期记忆插件，提供召回工具与设置页";
    descriptions.ja = "想起ツールと設定ページを備えた DSH の Noema 長期メモリプラグイン";
    homepage = "https://github.com/ZSeven-W/dsh-noema";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
