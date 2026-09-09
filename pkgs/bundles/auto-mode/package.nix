{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  jq,
  pnpmConfigHook,
  dshPnpm,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-auto-mode";
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "NanmiCoder";
    repo = "dsh-auto-mode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fRoJ9B+ZEJl45E1jgCHSu7aXYzqWkgbPLQUUo+NWKzw=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    pnpm = dshPnpm;
    fetcherVersion = 4;
    hash = "sha256-yskpj3TKREWF6OYOnADws5YNR9V5y7RdnOrwJfQ3NWQ=";
  };

  postPatch = ''
    if jq -e '.pnpm.overrides' package.json >/dev/null 2>&1; then
      jq '.pnpm | {overrides}' package.json > pnpm-workspace.yaml
      jq 'del(.pnpm, .overrides)' package.json > package.json.tmp
      mv package.json.tmp package.json
    fi
  '';

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [
    jq
    dshPnpm
  ];
  disallowedReferences = [ dshPnpm ];
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
