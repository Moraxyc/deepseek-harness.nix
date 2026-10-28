{
  lib,
  fetchFromGitHub,
  importPnpmLock,
  buildDshBundle,
  dsh-kernel,
  jq,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-auto-mode";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "NanmiCoder";
    repo = "dsh-auto-mode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZXXsfL0oHPSIHx5WsmT3muk+XkyCGEnJu410IyeJ+Jw=";
  };

  patches = [ ./alpha2-prompt-tools.patch ];

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpm_11;
    lockfileJson = ./pnpm-lock.json;
    fetcherVersion = 4;
  };

  postPatch = ''
    if jq -e '.pnpm.overrides' package.json >/dev/null 2>&1; then
      jq '.pnpm | {overrides}' package.json > pnpm-workspace.yaml
      jq 'del(.pnpm, .overrides)' package.json > package.json.tmp
      mv package.json.tmp package.json
    fi

    # Admit only the host version covered by the downstream compatibility check.
    test ${lib.escapeShellArg dsh-kernel.version} = 0.2.2-alpha.2
    jq --arg hostVersion "0.2.2-alpha.2" '
      .supportedHosts = if any(.supportedHosts[]; .version == $hostVersion)
        then .supportedHosts
        else .supportedHosts + [{version: $hostVersion, track: "current"}]
        end
      | .recommendedHost = $hostVersion
    ' compatibility.json > compatibility.json.tmp
    mv compatibility.json.tmp compatibility.json
  '';

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [
    jq
    pnpm_11
  ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@nanmicoder/dsh-auto-mode"
    mkdir -p "$appDir"

    cp -r package.json compatibility.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = ./update.sh;

  meta = {
    description = "Sandbox-first automatic permission policy for DeepSeek Harness";
    descriptions.zh-CN = "面向 DeepSeek Harness 的沙箱优先自动权限策略";
    homepage = "https://github.com/NanmiCoder/dsh-auto-mode";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
