{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-better-sidebar";
  version = "0.32.1";
  deployPackage = "dsh-better-sidebar";
  stripPrepareScripts = true;
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "DSH-better-sidebar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PfZAv548WWD8nuGAtkQmMP1nCRC0LK/BV3uYsdLak3I=";
  };

  pnpmDepsHash = "sha256-dRT2GD0ephYT+rOYjjroEf5Ju9QdihVLYJGlAfgM66Y=";

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
    descriptions.ja = "DSH Web UI に VS Code 風の右サイドバーを提供";
    homepage = "https://github.com/omdsh-dev/DSH-better-sidebar";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
