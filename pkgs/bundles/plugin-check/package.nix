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
  pname = "dsh-plugin-check";
  inherit (dshSources."bundles.plugin-check") version src;

  # Upstream commits the generated lib and has no runtime dependencies. Its
  # lockfile omits registry metadata, so do not resolve dev-only tooling here.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = dshSources."bundles.plugin-check".npmDepsHash;
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontNpmBuild = true;
  installation = dsh-runtime;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@omdsh-dev/dsh-plugin-check"
    mkdir -p "$appDir"
    cp ${finalAttrs.src}/package.json "$appDir/"
    cp -r cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    packageLock = {
      name = "@omdsh-dev/dsh-plugin-check";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@omdsh-dev/dsh-plugin-check";
        version = finalAttrs.version;
      };
    };

  };

  meta = {
    description = "Read-only DSH plugin health checker for manifest, patch, build, and registry diagnostics";
    descriptions.zh-CN = "只读检查 DSH 插件清单、补丁、构建与注册状态的健康检查工具";
    descriptions.ja = "DSH プラグインのマニフェスト、パッチ、ビルド、レジストリの状態を読み取り専用で診断するヘルスチェックツール";
    homepage = "https://github.com/omdsh-dev/dsh-plugin-check";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    # dsh 0.2.2-alpha.2 skips the bundle: it peers on dsh-invariants, removed in 0.2.1-alpha.1, and dsh-tools <0.2.0.
    broken = true;
  };
})
