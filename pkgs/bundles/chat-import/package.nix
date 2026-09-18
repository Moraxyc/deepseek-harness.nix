{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-chat-import";
  version = "0.18.2";

  src = fetchFromGitHub {
    owner = "Nwflower";
    repo = "dsh-chat-import";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xzqItEDRFW59v1F8evX6XQuJvtsGigOdUQ/RWUMd8nI=";
  };

  npmDepsHash = "sha256-vPL18AT3db+yb3OEGLrQ27z/QYk1MYX3Q7UDoa6xpsg=";
  linkKernelNodeModules = dsh-kernel;

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Import external agent chat histories as resumable DeepSeek Harness sessions";
    descriptions.zh-CN = "将外部 Agent 聊天历史导入为可继续的 DeepSeek Harness 会话";
    homepage = "https://github.com/Nwflower/dsh-chat-import";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
