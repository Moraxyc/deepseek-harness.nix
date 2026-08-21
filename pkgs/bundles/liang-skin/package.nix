{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-client-liang-intensity-skin";
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "kingOfSoySauce";
    repo = "dsh-liang-skin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kemDL5fx60QiZDOaI3pjU1G/O8rq1qcq/TrJp+Uiygg=";
  };

  npmDepsHash = "sha256-WPmyKSAf/YrHhcd7dObPieNmMHsw1M2XW5nRgNayF58=";
  linkKernelNodeModules = dsh-kernel;

  passthru.updateScript = nix-update-script { extraArgs = [ "--flake" ]; };

  meta = {
    description = "Liang intensity reasoning slider skin for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供滑动变祖推理等级滑块皮肤";
    homepage = "https://github.com/kingOfSoySauce/dsh-liang-skin";
    platforms = lib.platforms.unix;
  };
})
