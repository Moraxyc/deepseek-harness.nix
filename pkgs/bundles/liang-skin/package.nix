{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-client-liang-intensity-skin";
  inherit (dshSources."bundles.liang-skin") version src;

  npmDepsHash = dshSources."bundles.liang-skin".npmDepsHash;
  installation = dsh-runtime;

  passthru.requiresWeb = true;

  meta = {
    description = "Liang intensity reasoning slider skin for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供滑动变祖推理等级滑块皮肤";
    descriptions.ja = "DeepSeek Harness 向けの Liang intensity 推論レベルスライダースキン";
    homepage = "https://github.com/kingOfSoySauce/dsh-liang-skin";
    platforms = lib.platforms.unix;
  };
})
