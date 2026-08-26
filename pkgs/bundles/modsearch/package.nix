{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-modsearch";
  version = "5.9.1";

  src = fetchFromGitHub {
    owner = "liustack";
    repo = "modsearch";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aRfQz+DDsEpAmKMpnURPM1Er9PR6RgW3PA8ynr9ffJ8=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-IrnTqej0JBHhZvkn88rF8QcpR2JcNmx1sxL/u0QIayc=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@liustack/modsearch"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml dist dsh docs skills CHANGELOG.md SECURITY.md README.md README.zh-CN.md LICENSE "$appDir/"
    cp -rL node_modules/commander node_modules/undici "$appDir/node_modules/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Native DSH web-search provider with X search and focused page-reading tools";
    descriptions.zh-CN = "原生 DSH 网页搜索 provider，并提供 X 搜索与聚焦网页阅读工具";
    homepage = "https://github.com/liustack/modsearch";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
