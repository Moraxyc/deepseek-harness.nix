{
  bashInteractive,
  lib,
  jq,
  makeWrapper,
  nodejs,
  nodejs-slim,
  stdenvNoCC,
  dsh-workspace,

  # Optional external Claude Code executable exposed through PATH.
  claudeCodePackage ? null,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-kernel";
  inherit (dsh-workspace) version;

  src = null;
  # The workspace is a build input, not part of the kernel runtime closure.
  disallowedReferences = [
    nodejs
    dsh-workspace
  ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    jq
    makeWrapper
  ];

  installPhase = ''
    workspaceApp="${dsh-workspace}/lib/dsh-workspace/kernel"
    appDir="$out/lib/deepseek-harness"

    mkdir -p "$appDir"
    cp -r "$workspaceApp/lib" "$appDir/lib"
    cp -r "$workspaceApp/config" "$appDir/config"
    cp "$workspaceApp/package.json" "$appDir/package.json"
    # Keep the public kernel self-contained; do not symlink back into the workspace.
    cp -r "$workspaceApp/node_modules" "$appDir/node_modules"
    jq '.name = "@deepseek-ai/dsh"' "$appDir/package.json" > "$appDir/package.json.tmp"
    mv "$appDir/package.json.tmp" "$appDir/package.json"

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs-slim} "$out/bin/dsh" \
      --add-flags "--expose-internals" \
      --add-flags "$appDir/lib/bin.js"

    runHook postInstall
  '';

  passthru = {
    runtimeDeps =
      lib.optionals stdenvNoCC.hostPlatform.isLinux [ bashInteractive ]
      ++ lib.optional (claudeCodePackage != null) claudeCodePackage;
  };

  meta = {
    description = "dsh kernel without profile bundles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
})
