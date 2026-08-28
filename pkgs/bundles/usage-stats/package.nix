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
  pname = "dsh-usage-stats";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "Ychris12138";
    repo = "dsh-usage-stats";
    rev = "16a683d1b6b7d5390e04e27afe3626d44e7b7804";
    hash = "sha256-3Htc/u/wBEPNnMlZl4vmwmSHqy2KLM22afKTtUeJ5yk=";
  };

  # The upstream repository commits the generated server and browser payloads.
  # Its lockfile contains only development-time React test dependencies.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-Cjf+rP2DFa/5zRSoNJ5AtnB6deKiAD10N4VnoGSWj6Q=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  linkKernelNodeModules = dsh-kernel;

  postPatch = ''
    jq 'del(.bin, .files, .scripts, .dependencies, .devDependencies, .peerDependencies, .peerDependenciesMeta)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@ychris12138/dsh-usage-stats"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    packageLock = {
      name = "@ychris12138/dsh-usage-stats";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@ychris12138/dsh-usage-stats";
        version = finalAttrs.version;
      };
    };

    updateScript = nix-update-script {
      extraArgs = [ "--flake" ];
    };
  };

  meta = {
    description = "Token usage, provider accounts, session cost estimates, budgets, and exports for the DSH Web UI";
    descriptions.zh-CN = "为 DSH Web 界面提供 Token 用量、Provider 账户、会话成本估算、预算与导出功能";
    homepage = "https://github.com/Ychris12138/dsh-usage-stats";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
