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
  pname = "dsh-plugin-liang-calibrator";
  version = "0-unstable-2026-08-17";

  src = fetchFromGitHub {
    owner = "BruzWJ";
    repo = "Liang-Saint-Slider";
    rev = "ff19dde9997f53e040eaed8bd7f0e91c0d56b4aa";
    hash = "sha256-2T9OrACDrBWIEv6i231YU9K5YL/+1YG+L9wwniuf5fw=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-ef3jm8lAxI2iH7X5BCplkC9KMFlPHygwd7pKwYRMKU4=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };
  linkKernelNodeModules = dsh-kernel;
  nativeBuildInputs = [ jq ];

  dontConfigure = true;
  dontBuild = true;

  postPatch = ''
    jq '.dsh.bundle.patch = "./cordis.patch.yml" | del(.peerDependencies, .peerDependenciesMeta)' package.json > package.json.tmp
    mv package.json.tmp package.json

    cat > cordis.patch.yml <<'YAML'
    - insert:
        - id: liang-calibrator
          name: dsh-plugin-liang-calibrator
    YAML

    cat > package-lock.json <<'JSON'
    {
      "name": "dsh-plugin-liang-calibrator",
      "version": "${finalAttrs.version}",
      "lockfileVersion": 3,
      "requires": true,
      "packages": {
        "": {
          "name": "dsh-plugin-liang-calibrator",
          "version": "${finalAttrs.version}"
        }
      }
    }
    JSON
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-plugin-liang-calibrator"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Liang intensity calibrator as a DeepSeek Harness model and thinking-effort slider";
    descriptions.zh-CN = "将 liang-intensity-calibrator 作为 DeepSeek Harness 的模型与思考强度滑块";
    homepage = "https://github.com/BruzWJ/Liang-Saint-Slider";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
