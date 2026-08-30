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
  version = "0.6.9";
  deployPackage = "dsh-at-file";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-at-file";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wm67LNPwIKwwLbWZ8gRF/5Tlllq5S+81Riwx1x72IXw=";
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

  patches = [ ./alpha-compat.patch ];

  preBuild = ''
    mkdir -p node_modules/@deepseek-ai
    # Keep declaration-merge providers local so TypeScript resolves them against ui-slots.
    for entry in ${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai/*; do
      name="$(basename "$entry")"
      case "$name" in
        dsh-client-locale|dsh-client-runtime|dsh-client-ui-conversation|dsh-client-ui-input-trigger|dsh-client-ui-settings)
          packageDir="node_modules/@deepseek-ai/$name"
          rm -rf "$packageDir"
          mkdir -p "$packageDir"
          cp "$entry/package.json" "$packageDir/package.json"
          cp -r "$entry/lib" "$packageDir/lib"
          chmod -R u+w "$packageDir"
          ;;
        *)
          ln -sfn "$entry" "node_modules/@deepseek-ai/$name"
          ;;
      esac
    done

    uiSlots="${dsh-workspace}/lib/dsh-workspace/client-packages/@deepseek-ai/dsh-client-ui-slots"
    rm -rf node_modules/@deepseek-ai/dsh-client-ui-slots
    cp -r "$uiSlots" node_modules/@deepseek-ai/dsh-client-ui-slots
    chmod -R u+w node_modules/@deepseek-ai/dsh-client-ui-slots

    clientStore="${dsh-workspace.cohort}/deepseek-ai-dsh-client-store-${dsh-workspace.version}.tgz"
    rm -rf node_modules/@deepseek-ai/dsh-client-store
    mkdir -p node_modules/@deepseek-ai/dsh-client-store
    tar -xzf "$clientStore" \
      -C node_modules/@deepseek-ai/dsh-client-store \
      --strip-components=1
    chmod -R u+w node_modules/@deepseek-ai/dsh-client-store
  '';

  postBuild = ''
    rm -rf \
      node_modules/@deepseek-ai/dsh-client-ui-slots \
      node_modules/@deepseek-ai/dsh-client-store \
      node_modules/@deepseek-ai/dsh-client-locale \
      node_modules/@deepseek-ai/dsh-client-runtime \
      node_modules/@deepseek-ai/dsh-client-ui-conversation \
      node_modules/@deepseek-ai/dsh-client-ui-input-trigger \
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
