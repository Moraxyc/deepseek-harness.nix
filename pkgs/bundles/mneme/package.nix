{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nodejs,
  nix-update-script,
}:

assert lib.versionAtLeast nodejs.version "24";

buildDshBundle (finalAttrs: {
  pname = "dsh-mneme";
  version = "0.7.1";

  # The runtime package lives under dsh-mneme/ in the upstream repository.
  src = fetchFromGitHub {
    owner = "modusensus";
    repo = "dsh-mneme";
    tag = "v${finalAttrs.version}";
    hash = "sha256-K7vSz7bg9rcNfwswJhEOOf636jM0pwh/1FZclSnJzDI=";
  };

  npmDeps = null;
  dontConfigure = true;
  linkKernelNodeModules = dsh-kernel;

  buildPhase = ''
    runHook preBuild
    node dsh-mneme/scripts/sync-lib.js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@modusensus/dsh-mneme"
    mkdir -p "$appDir/dsh-mneme"

    cp package.json "$appDir/"
    cp dsh-mneme/package.json dsh-mneme/cordis.patch.yml "$appDir/dsh-mneme/"
    cp -r dsh-mneme/lib "$appDir/dsh-mneme/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Persistent cross-session memory for DeepSeek Harness with local Markdown storage and autoDream consolidation";
    descriptions.zh-CN = "为 DeepSeek Harness 提供持久化跨会话记忆、本地 Markdown 存储与 autoDream 整理";
    homepage = "https://github.com/modusensus/dsh-mneme";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
