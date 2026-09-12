{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-chat-import";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "Nwflower";
    repo = "dsh-chat-import";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1a2jsdIWR8zfeJZ+K8AVPJZb1bFhZzOTwoVquvWipTg=";
  };

  npmDepsHash = "sha256-LHYOM6HuocjBACGXJ8NNDigHB/BoPhWJEW8M2zkyP0A=";
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
