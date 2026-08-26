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
  pname = "dsh-auto-mode";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "NanmiCoder";
    repo = "dsh-auto-mode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QVYlwTW2vmuWObJyWlyl9T5JsCkZWUfuccgKPacw+Fk=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-/Ou4vZGl2MJGG845H4mrI6Q5r8gzj40pZrZoSkk7Fo4=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@nanmicoder/dsh-auto-mode"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Sandbox-first automatic permission policy for DeepSeek Harness";
    descriptions.zh-CN = "面向 DeepSeek Harness 的沙箱优先自动权限策略";
    homepage = "https://github.com/NanmiCoder/dsh-auto-mode";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
