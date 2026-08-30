{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  git,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-turn-rewind";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "Anionex";
    repo = "dsh-turn-rewind";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xiG8vh/cZzGnTic/FnI58Q9SOhSfGAbHe6Utf4NS7yY=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-t9pQ/CkLntNdTsljBSvfGkel4Y+DrnLGVKn/dR0F9O4=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  # The peer and web client packages are supplied by the DSH kernel.
  linkKernelNodeModules = dsh-kernel;
  runtimeDeps = [ git ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@anionex/dsh-turn-rewind"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Turn-level conversation and workspace rewind for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的会话与工作区级回退插件";
    homepage = "https://github.com/Anionex/dsh-turn-rewind";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
