{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-agent-teams";
  version = "0.1.15";

  src = fetchFromGitHub {
    owner = "NanmiCoder";
    repo = "dsh-agent-teams";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qBrY6c7I4FAEI58I4jRifC4jzKFerQzikZ9AuajjRKo=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-8GgXKcwa0PyB5guVHwq3CNIjllZY8JrlgNmtM2t5kjs=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@nanmicoder/dsh-agent-teams"
    mkdir -p "$appDir/assets"
    cp -r package.json cordis.patch.yml lib "$appDir/"
    cp -r assets/agent-teams "$appDir/assets/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Multi-agent team collaboration for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的多 Agent 团队协作插件";
    homepage = "https://github.com/NanmiCoder/dsh-agent-teams";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
