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
  pname = "dsh-plugin-liang-calibrator";
  version = "0-unstable-2026-08-19";

  src = fetchFromGitHub {
    owner = "BruzWJ";
    repo = "Liang-Saint-Slider";
    rev = "530fa661245cc82ff9f10458089a3fd3ccec2e4a";
    hash = "sha256-0TLswr5JtrismW1zhTiWeiz2PsW/ryL1CbACJwJbIHk=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-5xQMQFMkF6yXQ2S7p/Xi4b0V/9hVBumsB55xMYiA72g=";
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

    cp ${writers.writeYAML "cordis.patch.yml" finalAttrs.passthru.cordisPatch} cordis.patch.yml

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-plugin-liang-calibrator"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    cordisPatch = [
      {
        insert = [
          {
            id = "liang-calibrator";
            name = "dsh-plugin-liang-calibrator";
          }
        ];
      }
    ];

    packageLock = {
      name = "dsh-plugin-liang-calibrator";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "dsh-plugin-liang-calibrator";
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
    description = "Liang intensity calibrator as a DeepSeek Harness model and thinking-effort slider";
    descriptions.zh-CN = "将 liang-intensity-calibrator 作为 DeepSeek Harness 的模型与思考强度滑块";
    homepage = "https://github.com/BruzWJ/Liang-Saint-Slider";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
