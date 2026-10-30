{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  copyTree,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  web-app,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-tui";
  version = "0.17.0";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    rev = "refs/tags/v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-+hMMxrJdT9uuOVM9oecg5J5SvkXtIQToCYZoKxrwTKw=";
  };

  patches = [
    ./alpha2-model-selection.patch
    # dsh 0.2.2-alpha.2 dropped the list-agents export and moved tool-ralph
    # into an optional bundle.
    ./alpha2-liangshen-delegation.patch
    ./btw-side-question-settle.patch
    ./verify-source-files.patch
    ./verify-host-contract-node-shebang.patch
    ./verify-rewind-edit-serial.patch
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
    prePnpmInstall = ''
      pnpm --dir vendor/dsh-std install \
        --ignore-scripts \
        --frozen-lockfile \
        --registry="$NIX_NPM_REGISTRY"
    '';
    hash = "sha256-ztdFdpwgWtIhBSqPbPib89lMPf+oxrdrGAuNpR1cZFQ=";
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;
  # Upstream peer ranges stop at 0.2.1-rc.3. Raise this only after the TUI
  # boots every bundled preset on the new dsh release.
  dshEngines = "0.2.2-alpha.2";
  linkKernelNodeModulesKeep = [
    "ansi-styles"
    # dsh-tui compiles against React 19, while dsh-kernel carries React 18.
    "react"
    # supports-hyperlinks@3.2.0 needs the supports-color@7 function export.
    "supports-color"
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@deepseek-harness-tui/dsh-tui"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml cordis.yml tui-profile presets lib bin assets guide "$appDir/"
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

    # Without a web-app row, dsh-tui registers the official presets from this
    # dev dependency, which is pinned to the 0.2.1 line.
    rm "$appDir/node_modules/@deepseek-ai/dsh-web-app"
    ln -s ${web-app}/lib/node_modules/@deepseek-ai/dsh-web-app \
      "$appDir/node_modules/@deepseek-ai/dsh-web-app"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    cd "$out/lib/node_modules/@deepseek-harness-tui/dsh-tui"
    node --input-type=module -e "
      import { readFileSync } from 'node:fs';
      const manifest = JSON.parse(readFileSync('package.json', 'utf8'));
      for (const specifier of Object.keys(manifest.imports)) {
        await import(specifier);
      }
    "

    runHook postInstallCheck
  '';

  passthru = {
    inherit (finalAttrs) pnpmDeps;
    requiresTui = true;
    requiresTty = true;

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--override-filename=pkgs/bundles/tui/package.nix"
      ];
    };
  };

  meta = {
    description = "Interactive terminal interface for dsh";
    descriptions.zh-CN = "dsh 的交互式终端界面";
    homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
