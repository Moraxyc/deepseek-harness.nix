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
  version = "1.4.5-unstable-2026-08-28";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-annotation";
    rev = "09fbc9bf7d30b12e7a3856fc4f65754a86fb4aff";
    hash = "sha256-ad3NOZ0hpZO87MZXQSofZ0lOVDFCml2ItC4gLMjZrcI=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-4RG2nRHl6bN5QmXYur2OT+780D22IzJTNhzqnLVSJrs=";
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
