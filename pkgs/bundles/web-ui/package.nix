{
  lib,
  stdenv,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  importPnpmLock,
  pnpmConfigHook,
  yq-go,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-web-ui";
  version = "0.3.20";
  deployPackage = "@linxin666/dsh-web-all";
  stripPrepareScripts = true;
  disableChildBundlePatches = true;
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "zhu1090093659";
    repo = "dsh-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kjD6HF1O47UrsV8lierw9+zzQCIcdMCQa7WgzsFnTmA=";
  };

  postPatch = ''
    yq -o=yaml '.' ${./pnpm-lock.json} > pnpm-lock.yaml
    printf '%s\n' \
      'manage-package-manager-versions=false' \
      'node-linker=hoisted' \
      >> .npmrc
  '';

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    package = lib.importJSON ./package.json;
    lockfileJson = ./pnpm-lock.json;
    workspaceJson = lib.importJSON ./pnpm-workspace.json;
    workspaceRoot = finalAttrs.src;
    fetcherVersion = 4;
    targetPlatform =
      if stdenv.buildPlatform == stdenv.hostPlatform then stdenv.targetPlatform else null;
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

  postNormalizeDeploy = ''
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
