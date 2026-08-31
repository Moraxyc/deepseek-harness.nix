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
  pname = "dsh-context";
  version = "0.38.5";

  src = fetchFromGitHub {
    owner = "bowenliang123";
    repo = "dsh-context";
    tag = "v${finalAttrs.version}";
    hash = "sha256-naQFpxCre3E5NLxcTC/UrHsLHFalEZsKs/OujMV0Fhg=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-a+f8uyaoI5gBA81IBtw7UsORm0YpJAksO1Rx/Tf4Kd4=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-context"
    mkdir -p "$appDir"
    cp -r LICENSE README.md cordis.patch.yml package.json lib "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Context insight and management plugin for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 上下文洞察与管理插件";
    homepage = "https://github.com/bowenliang123/dsh-context";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
