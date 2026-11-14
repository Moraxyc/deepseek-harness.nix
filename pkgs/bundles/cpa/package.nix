{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-cpa";
  inherit (dshSources."bundles.cpa") version src;

  npmDepsHash = dshSources."bundles.cpa".npmDepsHash;
  __darwinAllowLocalNetworking = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    node --test "tests/**/*.test.ts"
    runHook postCheck
  '';

  # The upstream peer ranges exclude this verified runtime.
  dshEngines = "0.2.2-rc.2";
  installation = dsh-runtime;

  passthru.requiresWeb = true;

  meta = {
    description = "CLI Proxy API provider and runtime plugin for dsh";
    descriptions.zh-CN = "dsh 的 CLI Proxy API（CPA）provider 与运行插件";
    descriptions.ja = "dsh 向け CLI Proxy API（CPA）プロバイダーおよびランタイムプラグイン";
    homepage = "https://github.com/Moraxyc/dsh-cpa";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
