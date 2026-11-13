{
  lib,
  fetchFromGitHub,
  fetchurl,
  buildDshBundle,
  dsh-runtime,
  nodejs,
  nix-update-script,
}:

let
  # Runtime dependencies pinned by the upstream package-lock.json.
  runtimeDependencies = {
    morphicons = fetchurl {
      url = "https://registry.npmjs.org/morphicons/-/morphicons-1.7.1.tgz";
      hash = "sha512-q5ylxy5/d7vBg0OAzanlooXf05PekovMYDuuQVpr6vAQZxl99lrJbaIi+jJ32PXQf9WEEaDO2pbNBsx1ZhEnFQ==";
    };
    yaml = fetchurl {
      url = "https://registry.npmjs.org/yaml/-/yaml-2.9.1.tgz";
      hash = "sha512-3NxN8+78OdzbT7C/WjGsyfPAtJaN3FNDsWxv7Y7mcDsT/oOmgW8BpyQQFFBnvZE3j9Y2Sdz1ULFLezL7Eb2yFw==";
    };
  };
in
assert lib.versionAtLeast nodejs.version "24";

buildDshBundle (finalAttrs: {
  pname = "dsh-mneme";
  version = "0.14.0";

  # The runtime package lives under dsh-mneme/ in the upstream repository.
  src = fetchFromGitHub {
    owner = "modusensus";
    repo = "dsh-mneme";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0oC056b84bu61xAUWndIA9+1kFnbl3q7bCKwVEzLRMw=";
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
    mkdir -p "$appDir/node_modules"
    archive=$(npm pack --ignore-scripts --loglevel error \
      --cache "$TMPDIR/npm-cache" --pack-destination "$TMPDIR" ./dsh-mneme)
    tar -xzf "$TMPDIR/$archive" --strip-components=1 -C "$appDir"

    ${lib.concatMapStringsSep "\n" (name: ''
      mkdir -p "$appDir/node_modules/${name}"
      tar -xzf ${runtimeDependencies.${name}} --strip-components=1 \
        -C "$appDir/node_modules/${name}"
    '') (builtins.attrNames runtimeDependencies)}

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
