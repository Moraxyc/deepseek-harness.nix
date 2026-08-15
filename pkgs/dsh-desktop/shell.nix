{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs-slim,
  electron_43,
}:

buildNpmPackage (finalAttrs: {
  pname = "dsh-desktop-shell";
  version = "0-unstable-2026-08-15";

  src = fetchFromGitHub {
    owner = "anywhere-labs";
    repo = "deepseek-harness-desktop";
    rev = "f9aa1b1a173e52705aa7e01bb734469a9dd247a8";
    hash = "sha256-5TXHilYxHVkm7wbDUJzW3ACFEbCsq8LtVKkyFtxlnO8=";
  };

  nodejs = nodejs-slim;
  disallowedReferences = [ pnpm_11 ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-JlGMxJ1OMX9kTTuqCiIH3OFMucjwlb8AVev/jqzMkSs=";
  };

  nativeBuildInputs = [
    nodejs-slim.npm
    pnpm_11
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build:desktop";

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    CI = "true";
  };

  installPhase = ''
    runHook preInstall

    cp -a ${electron_43.dist}/. "$out/"
    chmod -R u+w "$out"
    mv "$out/electron" "$out/DeepSeek Harness"

    mkdir -p "$out/resources/app"
    cp apps/desktop/package.json "$out/resources/app/package.json"
    cp -r apps/desktop/lib "$out/resources/app/lib"

    mkdir -p "$out/resources/desktop-resources"
    cp apps/desktop/resources/*.png "$out/resources/desktop-resources/"

    cp apps/desktop/build/icon.png "$out/icon.png"

    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness Electron shell, uncombined";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
