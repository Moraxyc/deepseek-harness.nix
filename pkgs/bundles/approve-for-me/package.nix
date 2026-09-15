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
  version = "0-unstable-2026-09-12";
  deployPackage = "dsh-approve-for-me";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "timeance";
    repo = "dsh-approve-for-me";
    rev = "b6da50375b93a8422d3459edd8b421e8b939fc5a";
    hash = "sha256-EANs2LG5x4AAJDRywYbcN8ZghQS26EGvzQP8+c2mXpA=";
  };

  pnpmDepsHash = "sha256-U+pXdayswunuzKfOH5izNqLuXUpt+ZDyAoUun5A4cdo=";

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
