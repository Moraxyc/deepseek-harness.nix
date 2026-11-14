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
  pname = "dsh-context";
  inherit (dshSources."bundles.context") version src;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = dshSources."bundles.context".pnpmDepsHash;
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  installation = dsh-runtime;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-context"
    mkdir -p "$appDir/node_modules"
    archive=$(npm pack --ignore-scripts --loglevel error \
      --cache "$TMPDIR/npm-cache" --pack-destination "$TMPDIR")
    tar -xzf "$TMPDIR/$archive" --strip-components=1 -C "$appDir"
    ${copyTree.followLinks {
      src = "node_modules/zod";
      dest = "$appDir/node_modules/zod";
    }}

    runHook postInstall
  '';

  passthru.requiresWeb = true;

  meta = {
    description = "Context insight and management plugin for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 上下文洞察与管理插件";
    descriptions.ja = "DeepSeek Harness のコンテキストを把握・管理するプラグイン";
    homepage = "https://github.com/bowenliang123/dsh-context";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
