{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
  nodejs,
  nix-update-script,
}:

assert lib.versionAtLeast nodejs.version "24";

buildDshBundle (finalAttrs: {
  pname = "dsh-mneme";
  version = "0.12.0";

  # The runtime package lives under dsh-mneme/ in the upstream repository.
  src = fetchFromGitHub {
    owner = "modusensus";
    repo = "dsh-mneme";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+VQpyJ292BpvPbm3Fd/a/LO9txduJ82gJSWmGjkSBRs=";
  };

  npmDeps = null;
  dontPatch = true;
  dontConfigure = true;
  installation = dsh-runtime;

  buildPhase = ''
    runHook preBuild
    node dsh-mneme/scripts/sync-lib.js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@modusensus/dsh-mneme"
    mkdir -p "$appDir"

    cp dsh-mneme/package.json dsh-mneme/cordis.patch.yml "$appDir/"
    cp -r dsh-mneme/lib "$appDir/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Persistent cross-session memory for DeepSeek Harness with local Markdown storage and autoDream consolidation";
    descriptions.zh-CN = "为 DeepSeek Harness 提供持久化跨会话记忆、本地 Markdown 存储与 autoDream 整理";
    descriptions.ja = "ローカル Markdown ストレージと autoDream による統合を備えた、DeepSeek Harness 向けの永続的なセッション間メモリ";
    homepage = "https://github.com/modusensus/dsh-mneme";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
