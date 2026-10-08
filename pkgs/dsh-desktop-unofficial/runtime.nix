{
  lib,
  copyTree,
  nodeModulesPrune,
  stdenvNoCC,
  dshHost,
  nodejs-slim,
}:

stdenvNoCC.mkDerivation {
  pname = "dsh-desktop-runtime";
  inherit (dshHost) version;

  src = null;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;

  nativeBuildInputs = [ nodejs-slim ];

  installPhase = ''
    runHook preInstall

    appDir="${dshHost}/lib/deepseek-harness"

    ${copyTree.preserve {
      src = "${dshHost.passthru.flattenedNodeModules}/node_modules";
      dest = "$out/node_modules";
    }}

    ${nodeModulesPrune.prune { tree = "$out/node_modules"; }}
    ${nodeModulesPrune.minify { tree = "$out/node_modules"; }}

    mkdir -p "$out/node_modules/@deepseek-ai/dsh"
    ${copyTree.followLinks {
      src = "$appDir/lib";
      dest = "$out/node_modules/@deepseek-ai/dsh/lib";
    }}
    ${copyTree.followLinks {
      src = "$appDir/config";
      dest = "$out/node_modules/@deepseek-ai/dsh/config";
    }}
    cp "$appDir/package.json" "$out/node_modules/@deepseek-ai/dsh/package.json"
    cp "$appDir/package.json" "$out/package.json"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    home="$TMPDIR/dsh-runtime-home"
    DSH_HOME="$home" ${lib.getExe nodejs-slim} --expose-internals \
      "$out/node_modules/@deepseek-ai/dsh/lib/bin.js" --version
    DSH_HOME="$home" ${lib.getExe nodejs-slim} --expose-internals \
      "$out/node_modules/@deepseek-ai/dsh/lib/bin.js" web --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Desktop Host runtime assembled from a composed dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
