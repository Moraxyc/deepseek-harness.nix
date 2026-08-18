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
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-web-ui";
  version = "0.2.0";
  deployPackage = "@linxin666/dsh-web-ui-all";
  stripPrepareScripts = true;
  disableChildBundlePatches = true;
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "zhu1090093659";
    repo = "dsh-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kbE25UiJfaIS3h7wCYMTcokwrc/7dkKero1uQRvq32c=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-lvLWn56WKdq6Q7WNTi1PtJXEPm168YCzYZmTdGE+qEY=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  preConfigure = ''
    # Ensure build-time bins such as tsc are resolvable from the pinned store.
    pnpm config set --location=project node-linker hoisted
  '';

  preBuild = ''
    for d in packages/*/node_modules; do
      [ -d "$d" ] || continue
      patchShebangs "$d"
    done
  '';

  postDeploy = ''
    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    mv \
      "$out/lib/package.json" \
      "$out/lib/cordis.patch.yml" \
      "$out/lib/lib" \
      "$deployPackagePath/"

    # Prune
    find "$out/lib/node_modules" -type f -path '*/build/*' ! -name '*.node' -delete
    find "$out/lib/node_modules" -depth -type d -empty -delete
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Extra web UI themes and components";
    descriptions.zh-CN = "额外的 Web UI 主题与组件";
    homepage = "https://github.com/zhu1090093659/dsh-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
