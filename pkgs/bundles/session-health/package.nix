{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-session-health";
  inherit (dshSources."bundles.session-health") version src;

  npmDepsHash = dshSources."bundles.session-health".npmDepsHash;
  npmBuildScript = "build";
  installation = dsh-runtime;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@deepseek-ai/dsh-session-health"
    mkdir -p "$appDir"
    cp -r LICENSE README.md README.en.md package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  meta = {
    description = "Read-only DSH session health checker for multi-frame zstd logs";
    descriptions.zh-CN = "只读检查 DSH 多帧 zstd 会话日志健康状况的插件";
    descriptions.ja = "マルチフレーム zstd セッションログの健全性を読み取り専用で確認する DSH プラグイン";
    homepage = "https://github.com/omdsh-dev/dsh-session-health";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    # dsh 0.2.2-alpha.2 skips the bundle: it peers on dsh-invariants, removed in 0.2.1-alpha.1, and dsh-tools <0.2.0.
    broken = true;
  };
})
