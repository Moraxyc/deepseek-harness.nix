{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  git,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-turn-rewind";
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "Anionex";
    repo = "dsh-turn-rewind";
    tag = "v${finalAttrs.version}";
    hash = "sha256-WZioe7KjPulaHDwE+CPjnwN606Uc8kueOZRq1Q1axAo=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-Ex99ufX83CIlxKD6UitEogoGt3U9SCrHBuguWyHtlUw=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  postInstall = ''
    settings="$out/lib/node_modules/@anionex/dsh-turn-rewind/lib/settings.js"
    substituteInPlace "$settings" \
      --replace-fail \
        "import { installSettingsSection, settingsNamespace } from '@deepseek-ai/dsh-settings';" \
        "" \
      --replace-fail \
        "export const TURN_REWIND_SETTINGS_NAMESPACE = settingsNamespace('turn-rewind');" \
        "export const TURN_REWIND_SETTINGS_NAMESPACE = 'turn-rewind';" \
      --replace-fail \
        "installSettingsSection(ctx, TURN_REWIND_SETTINGS_NAMESPACE, TurnRewindSettingsSchema, source(), {" \
        "ctx.inject(['settings'], (settingsCtx) => settingsCtx.settings.installSection(ctx, TURN_REWIND_SETTINGS_NAMESPACE, TurnRewindSettingsSchema, source(), {"
    sed -i \
      -e ':a' \
      -e '$!N' \
      -e '$!ba' \
      -e 's/    });\n}$/    }));\n}/' \
      "$settings"
  '';

  # The peer and web client packages are supplied by the DSH kernel.
  linkKernelNodeModules = dsh-kernel;
  runtimeDeps = [ git ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@anionex/dsh-turn-rewind"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Turn-level conversation and workspace rewind for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的会话与工作区级回退插件";
    homepage = "https://github.com/Anionex/dsh-turn-rewind";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
