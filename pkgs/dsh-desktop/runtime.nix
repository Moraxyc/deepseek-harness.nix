{
  lib,
  stdenvNoCC,
  dshHost,
}:
stdenvNoCC.mkDerivation {
  pname = "dsh-desktop-runtime";
  inherit (dshHost) version;

  src = null;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="${dshHost}/lib/deepseek-harness"

    mkdir -p "$out/node_modules/@deepseek-ai/dsh"
    cp -a "$appDir/node_modules/." "$out/node_modules/"
    chmod -R u+w "$out/node_modules"

    cp -a "$appDir/lib" "$out/node_modules/@deepseek-ai/dsh/lib"
    cp -a "$appDir/config" "$out/node_modules/@deepseek-ai/dsh/config"
    cp "$appDir/package.json" "$out/node_modules/@deepseek-ai/dsh/package.json"
    cp "$appDir/package.json" "$out/package.json"

    mkdir -p "$out/nix-support"
    cp "${dshHost}/nix-support/dsh-bundles.json" "$out/nix-support/dsh-bundles.json"

    runHook postInstall
  '';

  meta = {
    description = "Desktop Host runtime assembled from a composed dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
