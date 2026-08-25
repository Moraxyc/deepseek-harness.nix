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
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "Anionex";
    repo = "dsh-turn-rewind";
    tag = "v${finalAttrs.version}";
    hash = "sha256-NJe9yEfS5mkj0Hr17x/pXXGdmRRZ5CSwIzNY7s8fksw=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-KAXKkuYxk204hSfrRojFDqdYER0eiF0AlbIDbSJVROQ=";
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
