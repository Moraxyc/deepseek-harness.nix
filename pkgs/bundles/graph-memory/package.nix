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
  version = "2.0.0-unstable-2026-10-01";

  src = fetchFromGitHub {
    owner = "adoresever";
    repo = "graph-memory";
    rev = "5841b1987c3967998818764c9d4238add5f3aa7c";
    hash = "sha256-2l7dSv1T+bSKAYIu2dj+NVnqzsLiTMCNaL8R3yB1bhI=";
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
    hash = "sha256-oVguMvpw8jXwizeynHD8L5FM5KuUtW5kPoGFWJb8gpo=";
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
