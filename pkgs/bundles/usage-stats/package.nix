{
  lib,
  dshSources,
  fetchNpmDeps,
  buildDshBundle,
  dsh-runtime,
  jq,
  writers,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-usage-stats";
  inherit (dshSources."bundles.usage-stats") version src;

  # The upstream repository commits the generated server and browser payloads.
  # Its lockfile contains only development-time React test dependencies.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = dshSources."bundles.usage-stats".npmDepsHash;
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  installation = dsh-runtime;

  postPatch = ''
    jq 'del(.bin, .files, .scripts, .dependencies, .devDependencies, .peerDependencies, .peerDependenciesMeta)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@ychris12138/dsh-usage-stats"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    requiresWeb = true;
    packageLock = {
      name = "@ychris12138/dsh-usage-stats";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@ychris12138/dsh-usage-stats";
        version = finalAttrs.version;
      };
    };

  };

  meta = {
    description = "Token usage, provider accounts, session cost estimates, budgets, and exports for the DSH Web UI";
    descriptions.zh-CN = "为 DSH Web 界面提供 Token 用量、Provider 账户、会话成本估算、预算与导出功能";
    descriptions.ja = "DSH Web UI 向けのトークン使用量、プロバイダーアカウント、セッションコスト見積もり、予算、エクスポート機能";
    homepage = "https://github.com/Ychris12138/dsh-usage-stats";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
