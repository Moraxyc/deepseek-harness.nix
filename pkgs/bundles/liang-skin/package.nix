{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-client-liang-intensity-skin";
  version = "0.1.15-settings.4";

  src = fetchFromGitHub {
    owner = "kingOfSoySauce";
    repo = "dsh-liang-skin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aTjeKehOAbEWzFZcMZD+eDrKzwrVWwuGJCDlhbSi2Ps=";
  };

  npmDepsHash = "sha256-cgkiTbsmt8CLdnoKmGMW26cO2s/epumnFZoww7eosPE=";
  linkKernelNodeModules = dsh-kernel;

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script { extraArgs = [ "--flake" ]; };

  meta = {
    description = "Liang intensity reasoning slider skin for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供滑动变祖推理等级滑块皮肤";
    homepage = "https://github.com/kingOfSoySauce/dsh-liang-skin";
    platforms = lib.platforms.unix;
  };
})
