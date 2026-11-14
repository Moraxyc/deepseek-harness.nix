{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-ads";
  inherit (dshSources."bundles.ads") version src;
  deployPackage = "@nagi-ovo/dsh-ads";
  installation = dsh-runtime;

  pnpmDepsHash = dshSources."bundles.ads".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  passthru.requiresWeb = true;

  meta = {
    description = "DSH ad-infestation plugin with local portal ads and scam-ad parodies";
    descriptions.zh-CN = "DSH 广告插件，包含本地门户广告与诈骗广告仿制内容";
    descriptions.ja = "ローカルポータル広告と詐欺広告のパロディを表示する DSH 広告プラグイン";
    homepage = "https://github.com/Nagi-ovo/dsh-ads";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
