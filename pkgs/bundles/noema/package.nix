{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-noema";
  version = "0.1.0-rc.3";
  deployPackage = "@zseven-w/dsh-noema";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-noema";
    tag = "v${finalAttrs.version}";
    hash = "sha256-K9CPriKQJa+o1RO+tkfSzrCXC6WS0D2gQTwBza/Jg2c=";
  };

  pnpmDepsHash = "sha256-IgTpkTt5Js3abke85E8WMSWvuCP4yR8o2I/NqZMLPUM=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postPatch = ''
    substituteInPlace src/settings.ts \
      --replace-fail \
        "import { settingsNamespace } from '@deepseek-ai/dsh-settings'" \
        "import type {} from '@deepseek-ai/dsh-settings'" \
      --replace-fail \
        "export const NOEMA_MEMORY_SETTINGS_NS = settingsNamespace(NOEMA_MEMORY_SETTINGS_NAMESPACE)" \
        "export const NOEMA_MEMORY_SETTINGS_NS = NOEMA_MEMORY_SETTINGS_NAMESPACE"

    substituteInPlace src/client/index.tsx \
      --replace-fail \
        "import type { ClientContext } from '@deepseek-ai/dsh-client-runtime/client'" \
        "import type { Context as ClientContext } from '@deepseek-ai/cordis'"
    sed -i \
      "/dsh-client-locale\\/client/a import type {} from '@deepseek-ai/dsh-client-ui-renderer/client'" \
      src/client/index.tsx
  '';

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    mkdir -p node_modules/@deepseek-ai
    cp -rL ${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai/. node_modules/@deepseek-ai/
    rm -rf node_modules/@deepseek-ai/dsh-client-ui-slots
    cp -r ${dsh-workspace}/lib/dsh-workspace/client-packages/@deepseek-ai/dsh-client-ui-slots \
      node_modules/@deepseek-ai/dsh-client-ui-slots
    chmod -R u+w node_modules/@deepseek-ai/dsh-client-ui-slots

    for clientPackage in \
      dsh-api-remotes \
      dsh-client-connection \
      dsh-client-locale \
      dsh-client-ui-renderer \
      dsh-client-ui-settings; do
      archive="${dsh-workspace.cohort}/deepseek-ai-$clientPackage-${dsh-workspace.version}.tgz"
      packageDir="node_modules/@deepseek-ai/$clientPackage"
      rm -rf "$packageDir"
      mkdir -p "$packageDir"
      tar -xzf "$archive" -C "$packageDir" --strip-components=1
      chmod -R u+w "$packageDir"
    done
  '';

  postNormalizeDeploy = ''
    rm -rf \
      "$out/lib/node_modules/@deepseek-ai/dsh-client-ui-slots" \
      "$out/lib/node_modules/@deepseek-ai/dsh-api-remotes" \
      "$out/lib/node_modules/@deepseek-ai/dsh-client-connection" \
      "$out/lib/node_modules/@deepseek-ai/dsh-client-locale" \
      "$out/lib/node_modules/@deepseek-ai/dsh-client-ui-renderer" \
      "$out/lib/node_modules/@deepseek-ai/dsh-client-ui-settings" \
      "$deployPackagePath/node_modules/@deepseek-ai/dsh-client-ui-slots" \
      "$deployPackagePath/node_modules/@deepseek-ai/dsh-api-remotes" \
      "$deployPackagePath/node_modules/@deepseek-ai/dsh-client-connection" \
      "$deployPackagePath/node_modules/@deepseek-ai/dsh-client-locale" \
      "$deployPackagePath/node_modules/@deepseek-ai/dsh-client-ui-renderer" \
      "$deployPackagePath/node_modules/@deepseek-ai/dsh-client-ui-settings"
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=unstable"
    ];
  };

  meta = {
    description = "Noema long-term memory plugin for DSH with recall tools and a settings page";
    descriptions.zh-CN = "DSH 的 Noema 长期记忆插件，提供召回工具与设置页";
    homepage = "https://github.com/ZSeven-W/dsh-noema";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
