{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  jq,
  nix-update-script,
  writers,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-security-audit";
  version = "0-unstable-2026-09-09";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-security-audit";
    rev = "92ba784dfb0133ba5260bff00eb4b85697183ab9";
    hash = "sha256-pYw6YmMp1CkugQ3FENt96SAzk8E2VNFNYoQcSMkimdE=";
  };

  # Upstream commits the generated lib. The lockfile only contains build-time
  # dependencies, which are unnecessary when that payload is used directly.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-J3nZ2gh8Ua5zYJrpqyyzElMUFTRCSwxG4LCKy75dhCI=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontNpmBuild = true;
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@deepseek-ai/dsh-security-audit"
    mkdir -p "$appDir"
    cp ${finalAttrs.src}/package.json "$appDir/"
    cp -r cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    packageLock = {
      name = "@deepseek-ai/dsh-security-audit";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@deepseek-ai/dsh-security-audit";
        version = finalAttrs.version;
      };
    };

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--version=branch"
      ];
    };
  };

  meta = {
    description = "Read-only local DSH security audit for configuration, plugin provenance, sessions, and network exposure";
    descriptions.zh-CN = "只读审计 DSH 本地配置、插件来源、会话结构与网络暴露面的安全插件";
    homepage = "https://github.com/omdsh-dev/dsh-security-audit";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
