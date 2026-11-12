{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  copyTree,
  dsh-runtime,
  git,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-turn-rewind";
  version = "0.3.13";

  src = fetchFromGitHub {
    owner = "Anionex";
    repo = "dsh-turn-rewind";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rFGgEC99vl+CAd4IRPcnkxP7X2xf24F/fxFJtaGBLz8=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-Ex99ufX83CIlxKD6UitEogoGt3U9SCrHBuguWyHtlUw=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [
    pnpm_11
    git
  ];
  disallowedReferences = [ pnpm_11 ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    DSH_TURN_REWIND_HOST_ID="$(printf '%064d' 1)" node --test tests/*.test.mjs
    runHook postCheck
  '';

  # The peer and web client packages are supplied by the DSH installation.
  # The upstream peer ranges exclude this verified runtime.
  dshEngines = "0.2.2-rc.2";
  installation = dsh-runtime;
  runtimeDeps = [ git ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@anionex/dsh-turn-rewind"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml lib "$appDir/"
    ${copyTree.followLinks {
      src = "node_modules/ignore";
      dest = "$appDir/node_modules/ignore";
    }}

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Turn-level conversation and workspace rewind for DeepSeek Harness";
    descriptions.zh-CN = "DeepSeek Harness 的会话与工作区级回退插件";
    descriptions.ja = "DeepSeek Harness の会話とワークスペースをターン単位で巻き戻すプラグイン";
    homepage = "https://github.com/Anionex/dsh-turn-rewind";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
