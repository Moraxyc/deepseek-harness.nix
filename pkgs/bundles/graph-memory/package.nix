{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  yq-go,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-graph-memory";
  version = "2.0.0-unstable-2026-08-27";

  src = fetchFromGitHub {
    owner = "adoresever";
    repo = "graph-memory";
    rev = "443e6ccb9d1d37169404977199398f4b4935c4fc";
    hash = "sha256-LE64wK6526FoJNirasOxs9K+9AJhV1v7rQKB4pDtSdE=";
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
    hash = "sha256-4GQmxkxH+31oPUCdzBSzOF/wDhP6rLdrPTqFrkDFEcU=";
  };

  nativeBuildInputs = [
    yq-go
  ];
  npmBuildScript = "build";
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

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
