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
  version = "0-unstable-2026-08-28";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-security-audit";
    rev = "b4aced970599c594b0d7864340b92adc1207651b";
    hash = "sha256-+IU3DllxUj+rH5AZ3B3cj6CdqC0/BnFcZy2mU2JvW4U=";
  };

  # Upstream commits the generated lib. The lockfile only contains build-time
  # dependencies, which are unnecessary when that payload is used directly.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-gfiuacFdcTOOBTPlEIkUML5chvYqrMNw5jSrrWlrjls=";
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
