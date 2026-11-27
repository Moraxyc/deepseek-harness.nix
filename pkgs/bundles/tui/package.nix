{
  lib,
  dshSources,
  fetchPnpmDeps,
  buildDshBundle,
  copyTree,
  dsh-runtime,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-tui";
  inherit (dshSources."bundles.tui") version src;

  patches = [
    ./alpha2-model-selection.patch
    # dsh 0.2.2-alpha.2 dropped the list-agents export and moved tool-ralph
    # into an optional bundle.
    ./alpha2-liangshen-delegation.patch
    ./btw-side-question-settle.patch
    ./verify-source-files.patch
    ./verify-host-contract-node-shebang.patch
    ./verify-serial-gates.patch
  ];

  postPatch = ''
    chmod -R u+w vendor/dsh-std
  '';

  # Static imports initialize i18n before the verification script sets its language.
  env = {
    DSH_TUI_LANG = "en";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      patches
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    postPatch = finalAttrs.postPatch;
    # --force keeps every platform's optional binaries, as in the main install,
    # so the hash matches on all systems.
    prePnpmInstall = ''
      pnpm --dir vendor/dsh-std install \
        --force \
        --ignore-scripts \
        --frozen-lockfile \
        --registry="$NIX_NPM_REGISTRY"
    '';
    hash = dshSources."bundles.tui".pnpmDepsHash;
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  # The upstream peer ranges exclude the pinned runtime.
  overrideDshEngineVersion = true;
  installation = dsh-runtime;
  __darwinAllowLocalNetworking = true;
  installationKeep = [
    "ansi-styles"
    # dsh-tui compiles against React 19, while the installation carries React 18.
    "react"
    # supports-hyperlinks@3.2.0 needs the supports-color@7 function export.
    "supports-color"
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  preBuild = ''
    # Use Nix's CPU budget instead of the builder's full CPU count.
    export DSH_TUI_VERIFY_JOBS="$NIX_BUILD_CORES"
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@deepseek-harness-tui/dsh-tui"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml cordis.yml tui-profile presets lib bin cli assets locale guide "$appDir/"
    rm -rf "$appDir/cli/test"
    cp -r node_modules "$appDir/node_modules"

    # Workspace links point into vendor/dsh-std, which is not installed.
    rm -rf "$appDir/node_modules/@dsh-std"
    ${copyTree.followLinks {
      src = "node_modules/@dsh-std";
      dest = "$appDir/node_modules/@dsh-std";
    }}

    rm -rf "$appDir/node_modules/@dsh-tui-vendor"
    ${copyTree.followLinks {
      src = "node_modules/@dsh-tui-vendor";
      dest = "$appDir/node_modules/@dsh-tui-vendor";
    }}

    # Without a web-app row, dsh-tui registers this dependency's official presets.
    # Keep them aligned with the installation.
    rm "$appDir/node_modules/@deepseek-ai/dsh-web-app"
    ln -s ${dsh-runtime}/node_modules/@deepseek-ai/dsh-web-app \
      "$appDir/node_modules/@deepseek-ai/dsh-web-app"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    cd "$out/lib/node_modules/@deepseek-harness-tui/dsh-tui"
    node --input-type=module -e "
      import { accessSync, readFileSync } from 'node:fs';
      const manifest = JSON.parse(readFileSync('package.json', 'utf8'));
      for (const specifier of Object.keys(manifest.imports)) {
        await import(specifier);
      }
      for (const entry of Object.values(manifest.exports)) {
        for (const path of typeof entry === 'string' ? [entry] : Object.values(entry)) {
          accessSync(path);
        }
      }
    "
    node bin/dsh-tui.js cli --help

    runHook postInstallCheck
  '';

  passthru = {
    inherit (finalAttrs) pnpmDeps;
    requiresTui = true;
    requiresTty = true;
  };

  meta = {
    description = "Interactive terminal interface for dsh";
    descriptions.zh-CN = "dsh 的交互式终端界面";
    descriptions.ja = "dsh の対話型ターミナルインターフェース";
    homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
