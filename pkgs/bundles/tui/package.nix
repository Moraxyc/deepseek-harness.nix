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
  version = "0.8.5";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FDXXvBuIP+HF+6zfoJZZFLDq8FAxTX+MWstbi4t6uLc=";
  };

  postPatch = ''
    rm -rf vendor/dsh-std dsh-ecosystem-spec
    mkdir -p vendor/dsh-std dsh-ecosystem-spec
    cp -r ${finalAttrs.passthru.dshStd}/. vendor/dsh-std/
    cp -r ${finalAttrs.passthru.dshEcosystemSpec}/. dsh-ecosystem-spec/
    chmod -R u+w vendor/dsh-std dsh-ecosystem-spec
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
    hash = "sha256-GYwMjr/101805uudheyX85TvXZRWlxb72c9KMrOVKeI=";
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

    cp -r package.json cordis.patch.yml cordis.yml dsh-ecosystem-spec skills lib "$appDir/"
    # Bundle-private deps such as auto-bind and dsh-working-activity are not in
    # the kernel; linkKernelNodeModules merges the kernel peers into this tree.
    cp -r node_modules "$appDir/node_modules"

    # Workspace links point into vendor/dsh-std, which is not installed.
    rm -rf "$appDir/node_modules/@dsh-std"
    mkdir -p "$appDir/node_modules/@dsh-std"
    cp -rL node_modules/@dsh-std/. "$appDir/node_modules/@dsh-std/"

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
    inherit (finalAttrs) pnpmDeps;
    requiresTty = true;

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--subpackage=dshStd"
        "--subpackage=dshEcosystemSpec"
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
