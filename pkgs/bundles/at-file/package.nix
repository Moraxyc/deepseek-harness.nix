{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-at-file";
  version = "0.7.0";
  deployPackage = "dsh-at-file";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-at-file";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JU8JH9t2+72FW4FyGsOrZebGW0tPC7VzIkZuVfhlLmE=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-pTHoDj3MwGC4snJ5J8eKW0slfMdcEhvgmLgD+Kqa8eM=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  preBuild = ''
    # Build against the alpha.2 client cohort; the kernel carries host/runtime packages only.
    rm -rf node_modules/@deepseek-ai
    mkdir -p node_modules/@deepseek-ai
    cp -rL ${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai/. node_modules/@deepseek-ai/

    uiSlots="${dsh-workspace}/lib/dsh-workspace/client-packages/@deepseek-ai/dsh-client-ui-slots"
    rm -rf node_modules/@deepseek-ai/dsh-client-ui-slots
    cp -r "$uiSlots" node_modules/@deepseek-ai/dsh-client-ui-slots
    chmod -R u+w node_modules/@deepseek-ai/dsh-client-ui-slots

    for clientPackage in \
      dsh-api-remotes \
      dsh-api-session-controller \
      dsh-api-workspace-controller \
      dsh-client-connection \
      dsh-client-locale \
      dsh-client-store \
      dsh-client-ui-conversation \
      dsh-client-ui-input-trigger \
      dsh-client-ui-primitives \
      dsh-client-ui-renderer \
      dsh-client-ui-session \
      dsh-client-ui-workspace \
      dsh-client-ui-settings; do
      archive="${dsh-workspace.cohort}/deepseek-ai-$clientPackage-${dsh-workspace.version}.tgz"
      packageDir="node_modules/@deepseek-ai/$clientPackage"
      rm -rf "$packageDir"
      mkdir -p "$packageDir"
      tar -xzf "$archive" -C "$packageDir" --strip-components=1
      chmod -R u+w "$packageDir"
    done
  '';

  postBuild = ''
    rm -rf \
      node_modules/@deepseek-ai/dsh-client-ui-slots \
      node_modules/@deepseek-ai/dsh-api-remotes \
      node_modules/@deepseek-ai/dsh-api-session-controller \
      node_modules/@deepseek-ai/dsh-api-workspace-controller \
      node_modules/@deepseek-ai/dsh-client-connection \
      node_modules/@deepseek-ai/dsh-client-store \
      node_modules/@deepseek-ai/dsh-client-locale \
      node_modules/@deepseek-ai/dsh-client-ui-conversation \
      node_modules/@deepseek-ai/dsh-client-ui-input-trigger \
      node_modules/@deepseek-ai/dsh-client-ui-primitives \
      node_modules/@deepseek-ai/dsh-client-ui-renderer \
      node_modules/@deepseek-ai/dsh-client-ui-session \
      node_modules/@deepseek-ai/dsh-client-ui-workspace \
      node_modules/@deepseek-ai/dsh-client-ui-settings
  '';

  postDeploy = ''
    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    for entry in "$out"/lib/*; do
      case "$(basename "$entry")" in
        node_modules)
          continue
          ;;
      esac
      mv "$entry" "$deployPackagePath/"
    done
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Codex-style @path references for the DeepSeek Harness web GUI";
    descriptions.zh-CN = "为 DeepSeek Harness 网页界面提供 Codex 风格 @路径引用";
    homepage = "https://github.com/omdsh-dev/dsh-at-file";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
