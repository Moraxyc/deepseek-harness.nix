{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-visualize";
  version = "0.1.8-unstable-2026-11-06";
  deployPackage = "@nagi-ovo/dsh-visualize";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-visualize";
    rev = "b0946439d4dfe0ab8c66d25053e56383f3b487fd";
    hash = "sha256-BoyEI9o93l9ZsOGIG3XkXnFVV5wAlym5RbJ2YCcCe4w=";
  };

  pnpmDepsHash = "sha256-EkuOVSh7km8WSjXpS/B0HAsgUChwHDzVsoazHK2u1p8=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "DSH inline visualization plugin: render interactive HTML fragments as sandboxed cards";
    descriptions.zh-CN = "DSH 对话内可视化插件：模型调用 visualize 后，在 Web UI 中渲染可交互的沙箱卡片";
    descriptions.ja = "DSH のインライン可視化プラグイン。モデルが visualize を呼び出すと、対話型 HTML フラグメントを Web UI 内のサンドボックス化されたカードとして描画";
    homepage = "https://github.com/Nagi-ovo/dsh-visualize";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
