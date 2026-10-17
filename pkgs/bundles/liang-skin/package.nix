{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-client-liang-intensity-skin";
  version = "0.1.11";

  src = fetchFromGitHub {
    owner = "kingOfSoySauce";
    repo = "dsh-liang-skin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FpZXvv5KijVUvIVE1P84EX3LotYau90Nu5mgCu45enI=";
  };

  npmDepsHash = "sha256-XG030fiY7zh9/w0DV0FTOBJ/qAt5zXpRs2IhzOLIndA=";
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
