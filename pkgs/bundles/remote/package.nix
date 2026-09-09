{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-remote";
  version = "0.8.14";

  src = fetchFromGitHub {
    owner = "flymysql";
    repo = "dsh-remote";
    tag = "v${finalAttrs.version}";
    hash = "sha256-obAOuAGsA98x71BN6CHNl6Lvxm/sMdrbgj8UINhIQy4=";
  };

  npmDepsHash = "sha256-C/wsyABmlLE8k7FcAZn4EEsPEpVXO/1ekrZiGHTuMUA=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;
  postInstall = ''
    sidebar="$out/lib/node_modules/dsh-remote/node_modules/dsh-better-sidebar/lib/index.js"
    substituteInPlace "$sidebar" \
      --replace-fail \
        'import { SettingsConflictError, settingsNamespace } from "@deepseek-ai/dsh-settings";' \
        'import { SettingsConflictError } from "@deepseek-ai/dsh-settings";' \
      --replace-fail \
        'const ns = settingsNamespace(SIDEBAR_PREFS_NS);' \
        'const ns = SIDEBAR_PREFS_NS;'
  '';
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
    homepage = "https://github.com/flymysql/dsh-remote";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
