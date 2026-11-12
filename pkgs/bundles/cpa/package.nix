{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-cpa";
  version = "0.1.13";

  src = fetchFromGitHub {
    owner = "Moraxyc";
    repo = "dsh-cpa";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5aY1Re3V4nGvzrV4jOoRFqJ/Sl4Cd5Ar+exPzax6j7U=";
  };

  npmDepsHash = "sha256-6OxgwIYjrKN8L9wI15CUi4EYE7nw/BVhWyzbTWz6fJk=";
  __darwinAllowLocalNetworking = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    node --test "tests/**/*.test.ts"
    runHook postCheck
  '';

  # The upstream peer ranges exclude this verified runtime.
  dshEngines = "0.2.2-rc.2";
  installation = dsh-runtime;

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "CLI Proxy API provider and runtime plugin for dsh";
    descriptions.zh-CN = "dsh 的 CLI Proxy API（CPA）provider 与运行插件";
    descriptions.ja = "dsh 向け CLI Proxy API（CPA）プロバイダーおよびランタイムプラグイン";
    homepage = "https://github.com/Moraxyc/dsh-cpa";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
