{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-better-sidebar";
  version = "0.28.1";
  deployPackage = "dsh-better-sidebar";
  stripPrepareScripts = true;
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "DSH-better-sidebar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8Epfz8IIZEPLO7qFHrP1tyitr/u6GSyRRgDLtgdmdqA=";
  };

  pnpmDepsHash = "sha256-vXxJu35ihLTceJrXd6fXJZ9rGXCjz8NUE3BRG8UcVxE=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  preDeploy = ''
    jq 'del(.scripts.prepare)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  postNormalizeDeploy = ''
    find "$out/lib/node_modules" -type f -path '*/build/*' ! -name '*.node' -delete
    find "$out/lib/node_modules" -depth -type d -empty -delete
  '';

  passthru.requiresWeb = true;
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
