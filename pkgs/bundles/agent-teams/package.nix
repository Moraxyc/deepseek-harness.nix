{
  lib,
  dshSources,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  pnpm_10,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-agent-teams";
  inherit (dshSources."bundles.agent-teams") version src;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = dshSources."bundles.agent-teams".pnpmDepsHash;
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_10 ];
  disallowedReferences = [ pnpm_10 ];
  installation = dsh-runtime;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@nanmicoder/dsh-agent-teams"
    mkdir -p "$appDir/assets"
    cp -r package.json cordis.patch.yml lib "$appDir/"
    cp -r assets/agent-teams "$appDir/assets/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;

  meta = {
    description = "Multi-agent team collaboration for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的多 Agent 团队协作插件";
    descriptions.ja = "DeepSeek Harness 向けのマルチエージェントチーム連携プラグイン";
    homepage = "https://github.com/NanmiCoder/dsh-agent-teams";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
