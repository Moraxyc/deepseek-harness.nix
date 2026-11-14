{
  lib,
  dshSources,
  buildDshBundle,
  dshCohort,
  dsh-runtime,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-approve-for-me";
  inherit (dshSources."bundles.approve-for-me") version src;
  deployPackage = "dsh-approve-for-me";
  installation = dsh-runtime;

  pnpmDepsHash = dshSources."bundles.approve-for-me".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm exec vitest run
    runHook postCheck
  '';

  # The upstream plugin declares this as a peer but imports it from its host
  # module. The installation does not ship these browser client peers.
  postNormalizeDeploy = ''
    ${dshCohort.installPackages {
      dest = "$deployPackagePath/node_modules";
      names = [ "dsh-client-connection" ];
    }}
  '';

  passthru.requiresWeb = true;

  meta = {
    description = "Rule-gated automatic approval for DeepSeek Harness sandbox escalations";
    descriptions.zh-CN = "为 DeepSeek Harness 沙箱提权提供规则分流的自动审批插件";
    descriptions.ja = "DeepSeek Harness のサンドボックス権限昇格をルールに基づいて自動承認するプラグイン";
    homepage = "https://github.com/timeance/dsh-approve-for-me";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
