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
  version = "0.1.9-unstable-2026-11-07";
  deployPackage = "@nagi-ovo/dsh-visualize";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-visualize";
    rev = "af4efe7a59a36d4562b340ff50d771d2691cdc8c";
    hash = "sha256-PvkwTPtwFzcYXYVBN5IkqLFdzpc/3E7n8XE2yjti8Xw=";
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
