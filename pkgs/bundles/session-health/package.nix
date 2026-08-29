{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-session-health";
  version = "0-unstable-2026-08-28";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-session-health";
    rev = "6778dc8f2a5d658e3186c0c028f8c4842e821103";
    hash = "sha256-YaIEev2pPh2a727KNz3o7SdMZyctnAufQ+N0KTWzHbM=";
  };
  npmDepsHash = "sha256-J8l4N+zHM7iogI0osS7cLaS1cgMvYIw1wKGBdeuUuds=";
  npmBuildScript = "build";
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@deepseek-ai/dsh-session-health"
    mkdir -p "$appDir"
    cp -r LICENSE README.md README.en.md package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Read-only DSH session health checker for multi-frame zstd logs";
    descriptions.zh-CN = "只读检查 DSH 多帧 zstd 会话日志健康状况的插件";
    homepage = "https://github.com/omdsh-dev/dsh-session-health";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
