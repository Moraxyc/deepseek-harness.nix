{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-remote";
  version = "0.8.72";

  src = fetchFromGitHub {
    owner = "flymysql";
    repo = "dsh-remote";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lqpXNYcxddvn9WW7uBX9tIc1pgpdPazihUgkcd+5vnM=";
  };

  npmDepsHash = "sha256-9BEtoJsocFoL9vAzJau3z9PkUKlAY7cnHkJ9ji9n0NU=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;
  linkKernelNodeModules = dsh-kernel;
  # Keep the hard dependency local so a kernel-owned sidebar cannot replace it.
  linkKernelNodeModulesKeep = [ "dsh-better-sidebar" ];

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "SSH/SFTP remote workspaces, file operations, synchronization, and port forwarding for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供 SSH/SFTP 远程工作区、文件操作、同步与端口转发";
    descriptions.ja = "DeepSeek Harness 向けの SSH/SFTP リモートワークスペース、ファイル操作、同期、ポート転送";
    homepage = "https://github.com/flymysql/dsh-remote";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
