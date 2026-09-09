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
  pname = "dsh-tui";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-i49UdJ/uHCB1G7Jm7MPy/HDgbrCLUJjY9J1sl0xL6Mw=";
  };

  postPatch = ''
    rm -rf vendor/dsh-std dsh-ecosystem-spec dsh-auth
    mkdir -p vendor/dsh-std dsh-ecosystem-spec dsh-auth
    cp -r ${finalAttrs.passthru.dshStd}/. vendor/dsh-std/
    cp -r ${finalAttrs.passthru.dshEcosystemSpec}/. dsh-ecosystem-spec/
    cp -r ${finalAttrs.passthru.dshAuth}/. dsh-auth/
    chmod -R u+w vendor/dsh-std dsh-ecosystem-spec dsh-auth

    # fetchFromGitHub provides a tarball without a Git index, but verify:i18n
    # only needs the source file list for its static scan.
    substituteInPlace scripts/verify-i18n.ts \
      --replace-fail \
        "execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', 'src', 'scripts'], { encoding: 'utf8' })" \
        "execFileSync('find', ['src', 'scripts', '-type', 'f', '-print0'], { encoding: 'utf8' })"
  '';

  # Static imports initialize i18n before the verification script can set its
  # process-local language; pin build-time UI assertions in the locale-less Nix sandbox.
  env = {
    DSH_TUI_LANG = "en";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    postPatch = finalAttrs.postPatch;
    prePnpmInstall = ''
      pnpm --dir vendor/dsh-std install \
        --ignore-scripts \
        --frozen-lockfile \
        --registry="$NIX_NPM_REGISTRY"
    '';
    hash = "sha256-ZyR80zLuIQw4ZqrCwv/n3QDfqBLzj4MbZdZ0sJKJC9s=";
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

    cp -r package.json cordis.patch.yml cordis.yml dsh-ecosystem-spec presets lib "$appDir/"
    # Bundle-private deps such as auto-bind and dsh-working-activity are not in
    # the kernel; linkKernelNodeModules merges the kernel peers into this tree.
    cp -r node_modules "$appDir/node_modules"

    # Workspace links point into vendor/dsh-std, which is not installed.
    rm -rf "$appDir/node_modules/@dsh-std"
    mkdir -p "$appDir/node_modules/@dsh-std"
    cp -rL node_modules/@dsh-std/. "$appDir/node_modules/@dsh-std/"

    # dsh-auth is a workspace link in the source tarball and must be copied
    # into the final bundle instead of leaving a dangling link.
    rm -rf "$appDir/node_modules/@deepseek-harness-tui/dsh-auth"
    mkdir -p "$appDir/node_modules/@deepseek-harness-tui/dsh-auth"
    cp -rL node_modules/@deepseek-harness-tui/dsh-auth/. \
      "$appDir/node_modules/@deepseek-harness-tui/dsh-auth/"

    runHook postInstall
  '';

  passthru = {
    dshStd = fetchFromGitHub {
      owner = "Yan-Zero";
      repo = "dsh-std";
      rev = "614dfa1ac168db79fcf4577cf0ebb34e2e3b944b";
      hash = "sha256-aJEykWAXEKTUsNte51+ZEhFAgLT6QNNplNZTNPhgb00=";
    };
    dshEcosystemSpec = fetchFromGitHub {
      owner = "T-Auto";
      repo = "dsh-ecosystem-spec";
      rev = "d28c267fe7fd775428ec2dccd65b0b7efd4dacee";
      hash = "sha256-hhp/UUMo2engw0SyrB0Gq6Xc6BUYgvEmYh0F4OBdZEw=";
    };
    dshAuth = fetchFromGitHub {
      owner = "ccch1mneyyy";
      repo = "dsh-auth";
      rev = "94fdf81e775e8d884af4dfb64a94b617c3751936";
      hash = "sha256-gSkDJnjm4N2qOqnEstDU12S4D9FvomrxB9UVwlFN2M4=";
    };
    inherit (finalAttrs) pnpmDeps;
    requiresTui = true;
    requiresTty = true;

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--subpackage=dshStd"
        "--subpackage=dshEcosystemSpec"
        "--subpackage=dshAuth"
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
