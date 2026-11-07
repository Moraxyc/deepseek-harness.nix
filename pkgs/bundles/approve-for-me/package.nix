{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dshCohort,
  dsh-runtime,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-approve-for-me";
  version = "0-unstable-2026-11-06";
  deployPackage = "dsh-approve-for-me";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "timeance";
    repo = "dsh-approve-for-me";
    rev = "906a7e45ef7bb350049056f21c9ff4c15b142892";
    hash = "sha256-jI2RpQofncxEsfvVrdjjE/akd3Wjdho9++kNlgW7RO8=";
  };

  pnpmDepsHash = "sha256-iyrPUSYlVOXxMDX/eKy+QXiWeIRQAF0vySHvEmnXljo=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  # The upstream plugin declares this as a peer but imports it from its host
  # module. The installation does not ship these browser client peers.
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
    descriptions.ja = "DeepSeek Harness のサンドボックス権限昇格をルールに基づいて自動承認するプラグイン";
    homepage = "https://github.com/timeance/dsh-approve-for-me";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
