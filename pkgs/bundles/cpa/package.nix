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
  linkKernelNodeModules = dsh-kernel;

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "CLI Proxy API provider and runtime plugin for dsh";
    descriptions.zh-CN = "dsh 的 CLI Proxy API（CPA）provider 与运行插件";
    homepage = "https://github.com/Moraxyc/dsh-cpa";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    # dsh 0.2.2-alpha.2 skips the bundle: its @deepseek-ai/dsh-* peers pin 0.2.1-rc.2.
    broken = true;
  };
})
