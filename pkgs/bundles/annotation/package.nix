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
  version = "0-unstable-2026-08-22";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-annotation";
    rev = "599cd1e68c320da2def27574a57a4e5e786d757b";
    hash = "sha256-172xRkcuOdJX6bCAYl/5QlK2diICtvd/cPtLHma3j8s=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-x1P1fQw7bRSki7sGEHB+jWlxYY4woKhZjcbcRKJKXe4=";
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
      "name": "@omdsh-dev/dsh-annotation",
      "version": "${finalAttrs.version}",
      "lockfileVersion": 3,
      "requires": true,
      "packages": {
        "": {
          "name": "@omdsh-dev/dsh-annotation",
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

    appDir="$out/lib/node_modules/@omdsh-dev/dsh-annotation"
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
