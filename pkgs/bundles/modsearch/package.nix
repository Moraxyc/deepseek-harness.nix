{
  lib,
  dshSources,
  fetchPnpmDeps,
  buildDshBundle,
  copyTree,
  dsh-runtime,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-modsearch";
  inherit (dshSources."bundles.modsearch") version src;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = dshSources."bundles.modsearch".pnpmDepsHash;
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  installation = dsh-runtime;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@liustack/modsearch"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml dist dsh docs skills CHANGELOG.md SECURITY.md README.md README.zh-CN.md LICENSE "$appDir/"
    ${copyTree.followLinks {
      src = "node_modules/commander";
      dest = "$appDir/node_modules/commander";
    }}
    ${copyTree.followLinks {
      src = "node_modules/undici";
      dest = "$appDir/node_modules/undici";
    }}

    runHook postInstall
  '';

  passthru.requiresWeb = true;

  meta = {
    description = "Native DSH web-search provider with X search and focused page-reading tools";
    descriptions.zh-CN = "原生 DSH 网页搜索 provider，并提供 X 搜索与聚焦网页阅读工具";
    descriptions.ja = "X 検索とページの精読ツールを備えた DSH ネイティブの Web 検索プロバイダー";
    homepage = "https://github.com/liustack/modsearch";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
