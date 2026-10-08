{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  copyTree,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-tui";
  version = "0.14.0";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    rev = "refs/tags/v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-0Hy1vJdWx+qZHBF7hE/xmB0LeMZi+BtR1piXcyZ05TI=";
  };

  patches = [
    ./btw-side-question-settle.patch
    ./verify-source-files.patch
  ];

  postPatch = ''
    chmod -R u+w vendor/dsh-std
  '';

  # Static imports initialize i18n before the verification script can set its
  # process-local language; pin build-time UI assertions in the locale-less Nix sandbox.
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
    hash = "sha256-IGjAcrFryMNk++SRbF6cb8VnUn0cObc6FGcE4eNWLaA=";
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;
  # dsh-tui compiles against React 19, while dsh-kernel carries React 18.
  # supports-hyperlinks@3.2.0 needs the supports-color@7 function export,
  # while dsh-kernel carries 9.x.
  linkKernelNodeModulesKeep = [
    "ansi-styles"
    "react"
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
    # Retain private dependencies absent from the kernel.
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
