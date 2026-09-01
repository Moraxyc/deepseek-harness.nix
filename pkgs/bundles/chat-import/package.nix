{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-chat-import";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "Nwflower";
    repo = "dsh-chat-import";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+QF5FRYznqi4O7BynoXhUhwR6fL6POI1oEHJvACU3qg=";
  };

  npmDepsHash = "sha256-MrNa0H+IzLWiFGbdwcMfbGQRaqJt/CcYW1QrAZwTYpU=";
  linkKernelNodeModules = dsh-kernel;

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
