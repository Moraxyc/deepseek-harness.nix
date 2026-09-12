{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_10,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-agent-teams";
  version = "0.1.17";

  src = fetchFromGitHub {
    owner = "NanmiCoder";
    repo = "dsh-agent-teams";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Kma704LkKLykLlx9B06e3V7Wxmt/ZyECQV80yBtAvO4=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-qpArZpUWzfcacRBOHca7f503ttKg50XdOVgnfdZGVKY=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_10 ];
  disallowedReferences = [ pnpm_10 ];
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@nanmicoder/dsh-agent-teams"
    mkdir -p "$appDir/assets"
    cp -r package.json cordis.patch.yml lib "$appDir/"
    cp -r assets/agent-teams "$appDir/assets/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;
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
