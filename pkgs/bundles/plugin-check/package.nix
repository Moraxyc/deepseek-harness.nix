{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-plugin-check";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-plugin-check";
    rev = "5e51cb7e56f68e54cf50c36e1e0e9e959af696a7";
    hash = "sha256-tA/S3oel0wYK1MRguDaaTKQlQbgTZSZN+XUVCAJMuSU=";
  };

  npmDepsHash = "sha256-VsvYS9uAhZnoFMPOplFh1Xbdp2fgUSFqOl9uHCjH1W4=";
  npmBuildScript = "build";
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@omdsh-dev/dsh-plugin-check"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Read-only DSH plugin health checker for manifest, patch, build, and registry diagnostics";
    descriptions.zh-CN = "只读检查 DSH 插件清单、补丁、构建与注册状态的健康检查工具";
    homepage = "https://github.com/omdsh-dev/dsh-plugin-check";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
