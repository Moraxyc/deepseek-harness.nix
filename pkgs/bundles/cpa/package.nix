{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  runCommand,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-cpa";
  version = "0.1.4";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Moraxyc";
    repo = "dsh-cpa";
    tag = "v${finalAttrs.version}";
    hash = "sha256-52SRsynwWdzDT8x2OBGyjS7a9Zysk1lwDFm3pQ8fIYA=";
  };

  npmDeps = null;
  npmConfigHook = runCommand "noop-npm-config-hook" { } "mkdir -p $out";
  dontNpmBuild = true;
  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-cpa"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml src "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "CLI Proxy API provider and runtime plugin for dsh";
    descriptions.zh-CN = "dsh 的 CLI Proxy API（CPA）provider 与运行插件";
    homepage = "https://github.com/Moraxyc/dsh-cpa";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
