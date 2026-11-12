{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-client-liang-intensity-skin";
  version = "0.1.16";

  src = fetchFromGitHub {
    owner = "kingOfSoySauce";
    repo = "dsh-liang-skin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9xm9OM7GeLI0bJP4XUk4ELnQ86CMhcTcfONocz1dG9A=";
  };

  npmDepsHash = "sha256-byiodHjf32YnZiGQToR1Sfl/y+flX2CTJEwyiC3NnIY=";
  installation = dsh-runtime;

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script { extraArgs = [ "--flake" ]; };

  meta = {
    description = "Liang intensity reasoning slider skin for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供滑动变祖推理等级滑块皮肤";
    descriptions.ja = "DeepSeek Harness 向けの Liang intensity 推論レベルスライダースキン";
    homepage = "https://github.com/kingOfSoySauce/dsh-liang-skin";
    platforms = lib.platforms.unix;
  };
})
