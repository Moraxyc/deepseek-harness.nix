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
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    rev = "refs/tags/v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-yEFk4s3Q4AjB6I/DtBTJnabB5Qeof4nL3vE0PZkRfl0=";
  };

  # The side-question probe still needs its render-settle patch.
  patches = [ ./btw-side-question-settle.patch ];

  postPatch = ''
    chmod -R u+w vendor/dsh-std dsh-ecosystem-spec dsh-auth

    # fetchFromGitHub provides a tarball without a Git index, but verify:i18n
    # only needs the source file list for its static scan.
    substituteInPlace scripts/verify-i18n.ts \
      --replace-fail \
        "execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', 'src', 'scripts'], { encoding: 'utf8' })" \
        "execFileSync('find', ['src', 'scripts', '-type', 'f', '-print0'], { encoding: 'utf8' })"

    # Submodules lack a .git directory in the Nix sandbox.
    substituteInPlace scripts/verify-protocol-single-source.ts \
      --replace-fail \
        "const head = execFileSync('git', ['-C', specGitDir, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()" \
        "const { ECOSYSTEM_SPEC_REVISION: head } = await import('../src/adapter/standard/registry.js')" \
      --replace-fail \
        "const status = execFileSync('git', ['-C', specGitDir, 'status', '--short'], { encoding: 'utf8' }).trim()" \
        "const status = \"\""

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
      pnpm --dir dsh-auth install \
        --ignore-scripts \
        --frozen-lockfile \
        --registry="$NIX_NPM_REGISTRY"
    '';
    hash = "sha256-Ksdvr35vAN8bcUNhStCanShtirXuFGg55BjlmP2IQA8=";
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
    ${copyTree.followLinks {
      src = "node_modules/@dsh-std";
      dest = "$appDir/node_modules/@dsh-std";
    }}

    # dsh-auth is a workspace link in the source tarball and must be copied
    # into the final bundle instead of leaving a dangling link.
    rm -rf "$appDir/node_modules/@deepseek-harness-tui/dsh-auth"
    ${copyTree.followLinks {
      src = "node_modules/@deepseek-harness-tui/dsh-auth";
      dest = "$appDir/node_modules/@deepseek-harness-tui/dsh-auth";
    }}

    runHook postInstall
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
