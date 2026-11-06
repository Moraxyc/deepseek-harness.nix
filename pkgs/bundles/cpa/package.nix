{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-cpa";
  version = "0.1.12";

  src = fetchFromGitHub {
    owner = "Moraxyc";
    repo = "dsh-cpa";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wtIVxFw0AtnTz4wi8l37VX+4wzC6BlYOkRw81RL2FDM=";
  };

  npmDepsHash = "sha256-kSHppYZZK9c7c0xsTVWLIG5Nl7Y7OJ29vufu23J6mNA=";
  # The upstream peer ranges exclude this verified runtime.
  dshEngines = "0.2.2-rc.1";
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
