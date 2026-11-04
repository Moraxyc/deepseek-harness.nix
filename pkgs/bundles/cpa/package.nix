{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-cpa";
  version = "0.1.11";

  src = fetchFromGitHub {
    owner = "Moraxyc";
    repo = "dsh-cpa";
    tag = "v${finalAttrs.version}";
    hash = "sha256-756NgztT+evNeVNgH/anvQmJ4fMZ3Wt0O6JoHxGb5Yo=";
  };

  npmDepsHash = "sha256-Xd6erzQhvR674JdfBRZeMB6SNGnRvIEMoqSoso4JiyQ=";
  # Boots on 0.2.2-alpha.3; the upstream peer ranges predate it.
  dshEngines = "0.2.2-alpha.3";
  linkKernelNodeModules = dsh-kernel;

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
