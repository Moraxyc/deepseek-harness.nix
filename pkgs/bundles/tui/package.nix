{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-tui";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "ccch1mneyyy";
    repo = "dsh-TUI";
    rev = "f97c7cdce7fd38a24f8203087c24fd2172daa638";
    hash = "sha256-+rVXQB3NqsJxeQfA/6hfku368tvHJ4irxOmDLvj4xho=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-YGGVIWXUZscnUjHEX2Wb3VHW5eEhD58SIne0xXRPPgg=";
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-cc-tui"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml cordis.yml skills lib "$appDir/"

    # Keep the frozen install in the bundle. cordis and dsh peers resolve from
    # the kernel app.
    cp -r node_modules "$appDir/node_modules"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Interactive terminal interface for dsh";
    descriptions.zh-CN = "dsh 的交互式终端界面";
    homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
