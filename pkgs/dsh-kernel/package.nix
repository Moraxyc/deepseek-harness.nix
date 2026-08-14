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
  versionCheckHook,
  yq-go,
}:

let
  source = import ./source.nix { inherit fetchFromGitHub; };
  workspacePatch = mode: ''
    bash ${./workspace-patch.sh} ${mode}
  '';
  compositionBundleNames = [
    "@deepseek-ai/dsh-base"
    "@deepseek-ai/dsh-headless"
    "@deepseek-ai/dsh-web-app"
  ];
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-kernel";
  inherit (source) src version;

  nodejs = nodejs-slim;
  disallowedReferences = [ nodejs ];

  postPatch = workspacePatch "dependencies";

  preConfigure = ''
    bash ${./workspace-patch.sh} composition ${lib.concatMapStringsSep " " lib.escapeShellArg compositionBundleNames}
  '';

  # The patch uses mikefarah yq's `ea`, not the Python jq wrapper default.
  pnpmDeps = (fetchPnpmDeps.override { yq = yq-go; }) {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = source.pnpmDepsHash;
  };

  nativeBuildInputs = [
    jq
    makeWrapper
    nodejs-slim.npm
    pnpm_11
    python3
    yq-go
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  # node-pty's postinstall can't run before deploy assembles the composition
  preInstall = ''
    pnpm config set --location=project inject-workspace-packages true
    yq -i 'del(.scripts.postinstall)' packages/subprocess/subprocess-local/package.json
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/deepseek-harness"

    cp -r apps/cli/lib apps/nix-composition/lib
    cp -r apps/cli/config apps/nix-composition/config
    pnpm --filter @deepseek-ai/dsh-nix-composition deploy \
      --prod \
      --config.node-linker=hoisted \
      --config.link-workspace-packages=true \
      "$appDir"
    yq -i '.name = "@deepseek-ai/dsh"' "$appDir/package.json"

    # Prune
    rm -f "$appDir/node_modules/node-pty/build/"{{binding.,}Makefile,config.gypi,pty.target.mk}
    sed -i '1{/^#!/d;}' "$appDir/lib/bin.js"

    ${lib.getExe nodejs-slim} "$appDir/node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs"

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs-slim} $out/bin/dsh \
      --add-flags "--expose-internals" \
      --add-flags "$appDir/lib/bin.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    dshBundles = [ ];
  };

  meta = {
    description = "dsh kernel without profile bundles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
})
