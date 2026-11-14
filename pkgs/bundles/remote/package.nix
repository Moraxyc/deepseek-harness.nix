{
  lib,
  dshSources,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-remote";
  inherit (dshSources."bundles.remote") version src;

  npmDepsHash = dshSources."bundles.remote".npmDepsHash;
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;
  installation = dsh-runtime;
  # Keep the hard dependency local so the installation cannot replace it.
  installationKeep = [ "dsh-better-sidebar" ];

  passthru.requiresWeb = true;

  meta = {
    description = "SSH/SFTP remote workspaces, file operations, synchronization, and port forwarding for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供 SSH/SFTP 远程工作区、文件操作、同步与端口转发";
    descriptions.ja = "DeepSeek Harness 向けの SSH/SFTP リモートワークスペース、ファイル操作、同期、ポート転送";
    homepage = "https://github.com/flymysql/dsh-remote";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
