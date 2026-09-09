{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  dshPnpm,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-better-sidebar";
  version = "0.18.1";
  deployPackage = "dsh-better-sidebar";
  stripPrepareScripts = true;
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "DSH-better-sidebar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-2jUJgv8GHYZ+mSGjzToeqj66PxothU8jWwjsehRfx0E=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = dshPnpm;
    fetcherVersion = 4;
    hash = "sha256-oufGNNezyKGdVBeoS2wHKS1zpS5TSIu/kJQnBBhMdGA=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  preDeploy = ''
    jq 'del(.scripts.prepare)' package.json > package.json.tmp
    mv package.json.tmp package.json
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

    find "$out/lib/node_modules" -type f -path '*/build/*' ! -name '*.node' -delete
    find "$out/lib/node_modules" -depth -type d -empty -delete
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "VSCode-like right sidebar for the DSH web UI";
    descriptions.zh-CN = "为 DSH Web 界面提供 VSCode 风格右侧侧边栏";
    homepage = "https://github.com/omdsh-dev/DSH-better-sidebar";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
