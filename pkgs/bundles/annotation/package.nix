{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  jq,
  nix-update-script,
  writers,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-annotation";
  version = "1.4.3-unstable-2026-08-26";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-annotation";
    rev = "d0e024d2d7a771cc34aec3665308e4de45fcd950";
    hash = "sha256-IYTeb6QyIl2Ywnn4+vNDJr3GOJI9QzaaKiBzXtED44A=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-fJT4oHONQ0YSHcVekR3MAjkm84Nb+CnGCECW8hLQBoE=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  linkKernelNodeModules = dsh-kernel;

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

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--version=branch"
      ];
    };
  };

  meta = {
    description = "DSH Web selection annotation plugin: annotate assistant text and reply by numbered annotation";
    descriptions.zh-CN = "DSH Web 选区标注插件：标注助手文本，按编号回复对应标注";
    homepage = "https://github.com/omdsh-dev/dsh-annotation";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
