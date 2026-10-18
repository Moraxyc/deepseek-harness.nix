{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dshCohort,
  dsh-kernel,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-approve-for-me";
  version = "0-unstable-2026-10-17";
  deployPackage = "dsh-approve-for-me";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "timeance";
    repo = "dsh-approve-for-me";
    rev = "0fe15f0f8e564e46f5320ae945025b3fe0c94a85";
    hash = "sha256-0dD1lA09sxnaVbsc/2YVsMMgR11zz+G12XaKk+It1fg=";
  };

  pnpmDepsHash = "sha256-/Rb5lHgUY2Qs0J8qhpVoSZtxD+ePMXK/ByK2bJOJpBM=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  # The upstream plugin declares this as a peer but imports it from its host
  # module. The CLI kernel intentionally does not ship browser client peers.
  postNormalizeDeploy = ''
    ${dshCohort.installPackages {
      dest = "$deployPackagePath/node_modules";
      names = [ "dsh-client-connection" ];
    }}
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Rule-gated automatic approval for DeepSeek Harness sandbox escalations";
    descriptions.zh-CN = "为 DeepSeek Harness 沙箱提权提供规则分流的自动审批插件";
    homepage = "https://github.com/timeance/dsh-approve-for-me";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
