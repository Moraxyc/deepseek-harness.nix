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
  version = "0.9.3";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Fu4ujIj8JXS/npYNUUnruFUvI7HPyUGTKzP6qQdH/aQ=";
  };

  # dsh 0.1.2-alpha.4 renamed Session.events to snapshotEvents(); dsh-tui
  # 0.10.0-beta.3 still reads the old property on every session path, so the
  # bundle restores the alias on the kernel class (see the patch).
  patches = [ ./session-events-compat.patch ];

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
        "execSync('git ls-files src scripts', { encoding: 'utf8' })" \
        "execSync('find src scripts -type f -print', { encoding: 'utf8' })"
  '';

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
    hash = "sha256-KhiQi6uIG+ftXX9VNR3763xGXFrsxaGXG41ua/ArBF8=";
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;
  # dsh-tui compiles against React 19, while dsh-kernel carries React 18.
  linkKernelNodeModulesKeep = [
    "ansi-styles"
    "react"
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
      rev = "e1b902b0f95f4280a8e68d414ec7a4d25d6ce106";
      hash = "sha256-LVc7bMUJMI4GYW3IyBWYwFzkibayu6BgZxlO67FPtGk=";
    };
    dshAuth = fetchFromGitHub {
      owner = "ccch1mneyyy";
      repo = "dsh-auth";
      rev = "fba02bcf7fb57e3d9885f73882d5835ccdf526c4";
      hash = "sha256-ip/jdsm/YiPvVdZ0o2m/thImd+4ZmRjzQKzXvJ9dAK8=";
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
