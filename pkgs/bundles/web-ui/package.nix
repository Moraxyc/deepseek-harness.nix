{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch2,
  buildDshBundle,
  dsh-runtime,
  importPnpmLock,
  pnpmConfigHook,
  yq-go,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-web-ui";
  version = "0.4.16";
  deployPackage = "@linxin666/dsh-web-all";
  stripPrepareScripts = true;
  disableChildBundlePatches = true;
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "zhu1090093659";
    repo = "dsh-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mvk4VhghjMShZs3THtF77u8AMDclb3T2OAEJOImsR+U=";
  };

  patches = [
    (fetchpatch2 {
      url = "https://github.com/zhu1090093659/dsh-web-ui/commit/971cc3e1f6f5b52bbcd86802a9be0e0c50fc32f1.patch";
      hash = "sha256-/jkgzKLBXq3y5v7SzKgmsAfhlXkHpmhJG41h1QAbuHM=";
      includes = [
        "packages/dsh-agents/src/index.ts"
        "packages/dsh-agents/src/team/index.ts"
        "packages/dsh-agents/src/team/roster.ts"
        "packages/dsh-agents/tests/apply-inject.spec.ts"
        "packages/dsh-agents/tests/team-runtime.spec.ts"
        "packages/dsh-agents/tsdown.config.ts"
        "packages/dsh-liangshen/presets/liangshen/dispatch-guard.mjs"
        "packages/dsh-liangshen/tests/dispatch-guard.test.ts"
      ];
    })
  ];

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

  __darwinAllowLocalNetworking = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm --dir packages/dsh-agents exec vitest run tests/apply-inject.spec.ts tests/team-runtime.spec.ts
    pnpm --dir packages/dsh-liangshen exec vitest run tests/dispatch-guard.test.ts
    runHook postCheck
  '';

  postNormalizeDeploy = ''
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
    descriptions.ja = "追加の Web UI テーマとコンポーネント";
    homepage = "https://github.com/zhu1090093659/dsh-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
