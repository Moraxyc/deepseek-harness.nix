{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-mnemon";
  version = "0.5.45";
  deployPackage = "dsh-mnemon";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-mnemon";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Nvomg7Pzrryr6IfA9g+8FDwqQvPWZGzyfP7pm1nPoNw=";
  };

  pnpmDepsHash = "sha256-H+IBGNuymboUzmw2E8lfqsfRdSlpCTd16eKkiWYQ6C4=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  installation = dsh-runtime;

  __darwinAllowLocalNetworking = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm exec vitest run tests/activation-agent-compat.spec.ts tests/subagent-start.spec.ts
    runHook postCheck
  '';

  # The root build does not build the source-only plugin workspaces, while
  # deploy intentionally skips dependency lifecycle scripts.
  preDeploy = ''
    pnpm --workspace-concurrency=4 --config.ignore-workspace-cycles=true -r build
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Composable three-tier memory control plane for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的可组合三层记忆控制平面";
    descriptions.ja = "DeepSeek Harness 向けの構成可能な 3 層メモリコントロールプレーン";
    homepage = "https://github.com/omdsh-dev/dsh-mnemon";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
