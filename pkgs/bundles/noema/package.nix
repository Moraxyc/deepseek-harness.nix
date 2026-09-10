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
  version = "0.1.0-rc.4";
  deployPackage = "@zseven-w/dsh-noema";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-noema";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CuMTu7FOH77e+T6WSgFa5/1GqdYftBlI3gLzi9SUKQE=";
  };

  pnpmDepsHash = "sha256-4NAETbjerUa61o3AOUpsQGlV8bVttk31Lr8HJjslc/A=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

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
