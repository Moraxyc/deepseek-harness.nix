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
  pname = "dsh-annotation";
  inherit (dshSources."bundles.annotation") version src;

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = dshSources."bundles.annotation".npmDepsHash;
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  installation = dsh-runtime;

  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@changfenhuang/dsh-annotation"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml client.js lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    requiresWeb = true;
    packageLock = {
      name = "@changfenhuang/dsh-annotation";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@changfenhuang/dsh-annotation";
        version = finalAttrs.version;
      };
    };

  };

  meta = {
    description = "DSH Web selection annotation plugin: annotate assistant text and reply by numbered annotation";
    descriptions.zh-CN = "DSH Web 选区标注插件：标注助手文本，按编号回复对应标注";
    descriptions.ja = "DSH Web の選択範囲注釈プラグイン。アシスタントのテキストに注釈を付け、注釈番号を指定して返信";
    homepage = "https://github.com/omdsh-dev/dsh-annotation";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
