{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  nodejs-slim,
  python3,
  yq-go,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-graph-memory";
  version = "1.6.0-beta.8";

  src = fetchFromGitHub {
    owner = "adoresever";
    repo = "graph-memory";
    rev = "66183143b67bf7c337fa7ce31343435b8635ea95";
    hash = "sha256-o39jez5zhevFoWSO9vzDla3MlchEqITYoHzJ6vKlLDo=";
  };

  postPatch = ''
    yq -o=json \
      '.scripts |= del(.prepare, .prepack) | .devDependencies |= del(.vitest)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    nativeBuildInputs = [ yq-go ];
    hash = "sha256-rIcB7xmFmC12OggUaWbAzznldgQMb6ZMukAw2jB5Hrw=";
  };

  nativeBuildInputs = [
    python3
    yq-go
  ];
  disallowedReferences = [ python3 ];
  npmBuildScript = "build";
  linkKernelNodeModules = dsh-kernel;

  preBuild = ''
    rm -rf node_modules/@photostructure/sqlite/prebuilds
    (
      cd node_modules/@photostructure/sqlite
      ${nodejs-slim}/bin/node \
        ${nodejs-slim.npm}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js \
        rebuild
    )
  '';

  installPhase = ''
    runHook preInstall

    # Keep only the native module; node-gyp's generated build files retain
    # references to the build-time Node.js and Python paths.
    find node_modules/@photostructure/sqlite/build \
      -type f ! -name phstr_sqlite.node -delete
    find node_modules/@photostructure/sqlite/build -depth -type d -empty -delete

    appDir="$out/lib/node_modules/graph-memory"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml LICENSE dist node_modules "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
      "--generate-lockfile"
    ];
  };

  meta = {
    description = "Native DSH graph memory with SQLite, FTS5 fallback, graph traversal, PageRank, and cross-session recall";
    descriptions.zh-CN = "原生 DSH 知识图谱记忆插件，提供 SQLite、FTS5 降级、图遍历、PageRank 与跨会话召回";
    homepage = "https://github.com/adoresever/graph-memory";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
