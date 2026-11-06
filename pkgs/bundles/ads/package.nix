{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-ads";
  version = "0.1.3-unstable-2026-11-06";
  deployPackage = "@nagi-ovo/dsh-ads";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "Nagi-ovo";
    repo = "dsh-ads";
    rev = "856b123090e87ed023033894d9734ffe3142cc7c";
    hash = "sha256-/Dg/4b9sCSS1Hb9DaAxKFzkSTRsXZFcTRprVNF6OlIc=";
  };

  pnpmDepsHash = "sha256-3KYwS/IN8BAq/gMBqvZnVRzRyMJJQGkmiQ3TP4yOyrA=";

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
    description = "DSH ad-infestation plugin with local portal ads and scam-ad parodies";
    descriptions.zh-CN = "DSH 广告插件，包含本地门户广告与诈骗广告仿制内容";
    descriptions.ja = "ローカルポータル広告と詐欺広告のパロディを表示する DSH 広告プラグイン";
    homepage = "https://github.com/Nagi-ovo/dsh-ads";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
