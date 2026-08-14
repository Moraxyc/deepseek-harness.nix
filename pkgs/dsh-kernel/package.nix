{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  jq,
  makeWrapper,
  nodejs,
  nodejs-slim,
  pnpmConfigHook,
  pnpm_11,
  python3,
  stdenvNoCC,
  versionCheckHook,
  yq-go,

  # Optional external Claude Code executable exposed through PATH.
  claude-code ? null,
}:

let
  workspace = import ./workspace.nix {
    inherit
      buildNpmPackage
      fetchFromGitHub
      fetchPnpmDeps
      jq
      lib
      nodejs
      nodejs-slim
      pnpmConfigHook
      pnpm_11
      python3
      yq-go
      ;
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-kernel";
  inherit (workspace) version;

  src = null;
  disallowedReferences = [ nodejs ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    jq
    makeWrapper
  ];

  installPhase = ''
    workspaceApp="${workspace}/lib/dsh-workspace/kernel"
    appDir="$out/lib/deepseek-harness"

    mkdir -p "$appDir"
    cp -r "$workspaceApp/lib" "$appDir/lib"
    cp -r "$workspaceApp/config" "$appDir/config"
    cp "$workspaceApp/package.json" "$appDir/package.json"
    ln -s "$workspaceApp/node_modules" "$appDir/node_modules"
    jq '.name = "@deepseek-ai/dsh"' "$appDir/package.json" > "$appDir/package.json.tmp"
    mv "$appDir/package.json.tmp" "$appDir/package.json"

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs-slim} "$out/bin/dsh" \
      --add-flags "--expose-internals" \
      --add-flags "$appDir/lib/bin.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    inherit workspace;
    dshBundles = [ ];
    runtimeDeps = [ claude-code ];
  };

  meta = {
    description = "dsh kernel without profile bundles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
})
