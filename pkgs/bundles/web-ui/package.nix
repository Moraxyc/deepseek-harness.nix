{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  importPnpmLock,
  pnpmConfigHook,
  pnpm_11,
  yq-go,
}:
let
  fetchPnpmDeps' = fetchPnpmDeps.override { yq = yq-go; };
in
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-web-ui";
  version = "0.3.10";
  deployPackage = "@linxin666/dsh-web-all";
  stripPrepareScripts = true;
  disableChildBundlePatches = true;
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "zhu1090093659";
    repo = "dsh-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dBbcq1+vEqVnRAi9HiFJIv0zetUmwq36OyZKkvUAf/c=";
  };

  postPatch = ''
    DSH_WEB_UI_LOCK=${./pnpm-lock.json} \
      yq -i '.overrides = load(strenv(DSH_WEB_UI_LOCK)).overrides' pnpm-workspace.yaml
    yq -o=yaml '.' ${./pnpm-lock.json} > pnpm-lock.yaml
    printf '%s\n' \
      'manage-package-manager-versions=false' \
      'node-linker=hoisted' \
      >> .npmrc
  '';

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    fetchPnpmDeps = fetchPnpmDeps';
    lockfileJson = ./pnpm-lock.json;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    targetPlatform =
      if stdenv.buildPlatform == stdenv.hostPlatform then stdenv.targetPlatform else null;
    patchedDependencySources = {
      "@morlay/ui-conversation-message-actions@0.0.11" =
        "${finalAttrs.src}/patches/@morlay__ui-conversation-message-actions@0.0.11.patch";
    };
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ yq-go ];

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

  passthru = {
    updateScript = ./update.sh;
    requiresWeb = true;
  };

  meta = {
    description = "Extra web UI themes and components";
    descriptions.zh-CN = "额外的 Web UI 主题与组件";
    homepage = "https://github.com/zhu1090093659/dsh-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
