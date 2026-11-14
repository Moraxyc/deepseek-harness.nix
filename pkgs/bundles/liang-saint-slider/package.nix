{
  lib,
  dshSources,
  fetchNpmDeps,
  buildDshBundle,
  dsh-runtime,
  jq,
  writers,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-plugin-liang-calibrator";
  inherit (dshSources."bundles.liang-saint-slider") version src;

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = dshSources."bundles.liang-saint-slider".npmDepsHash;
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };
  installation = dsh-runtime;
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
    requiresWeb = true;
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

  };

  meta = {
    description = "Liang intensity calibrator as a DeepSeek Harness model and thinking-effort slider";
    descriptions.zh-CN = "将 liang-intensity-calibrator 作为 DeepSeek Harness 的模型与思考强度滑块";
    descriptions.ja = "liang-intensity-calibrator を DeepSeek Harness のモデル・思考強度スライダーとして提供";
    homepage = "https://github.com/BruzWJ/Liang-Saint-Slider";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
