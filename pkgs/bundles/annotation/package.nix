{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  jq,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-annotation";
  version = "0-unstable-2026-08-25";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-annotation";
    rev = "bc4d7926d0e22e0db6c1f6a94539bcf93fe07ac9";
    hash = "sha256-uM9qWFN+5MZ5i3TLygruQqzi6R7R7DNRqIiqFoiZp6c=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-2EQ4yy9mJPwX14ODw8HT/aOiKQqVfhDw2wdNU+QW/8I=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  linkKernelNodeModules = dsh-kernel;

  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cat > package-lock.json <<'JSON'
    {
      "name": "@changfenhuang/dsh-annotation",
      "version": "${finalAttrs.version}",
      "lockfileVersion": 3,
      "requires": true,
      "packages": {
        "": {
          "name": "@changfenhuang/dsh-annotation",
          "version": "${finalAttrs.version}"
        }
      }
    }
    JSON
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

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "DSH Web selection annotation plugin: annotate assistant text and reply by numbered annotation";
    descriptions.zh-CN = "DSH Web 选区标注插件：标注助手文本，按编号回复对应标注";
    homepage = "https://github.com/omdsh-dev/dsh-annotation";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
