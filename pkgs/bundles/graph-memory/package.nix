{
  lib,
  dshSources,
  fetchNpmDeps,
  buildDshBundle,
  dsh-runtime,
  yq-go,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-graph-memory";
  inherit (dshSources."bundles.graph-memory") version src;

  postPatch = ''
    yq -o=json \
      '.scripts |= del(.prepare, .prepack) | .devDependencies |= del(.vitest)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${dshSources."bundles.graph-memory".artifacts."package-lock.json"} package-lock.json
  '';

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    nativeBuildInputs = [ yq-go ];
    hash = dshSources."bundles.graph-memory".npmDepsHash;
  };

  nativeBuildInputs = [
    yq-go
  ];
  npmBuildScript = "build";
  installation = dsh-runtime;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/graph-memory"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml LICENSE dist node_modules "$appDir/"

    runHook postInstall
  '';

  meta = {
    description = "Native DSH graph memory with SQLite, FTS5 fallback, graph traversal, PageRank, and cross-session recall";
    descriptions.zh-CN = "原生 DSH 知识图谱记忆插件，提供 SQLite、FTS5 降级、图遍历、PageRank 与跨会话召回";
    descriptions.ja = "SQLite、FTS5 フォールバック、グラフ探索、PageRank、セッション間の想起に対応した DSH ネイティブの知識グラフメモリプラグイン";
    homepage = "https://github.com/adoresever/graph-memory";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
