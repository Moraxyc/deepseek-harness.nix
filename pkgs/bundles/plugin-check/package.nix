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
  pname = "dsh-plugin-check";
  version = "0-unstable-2026-09-01";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-plugin-check";
    rev = "1be9c22748e0de3e3da44a737aa06a91ec370750";
    hash = "sha256-kUi5VZQoVrbYnWvwDii+4PFl1VBxUVA+gcgf46BYeu8=";
  };

  # Upstream commits the generated lib and has no runtime dependencies. Its
  # lockfile omits registry metadata, so do not resolve dev-only tooling here.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-3u0vMa9Y/Meu2/Cxgbig8RzDTzIEGqYJXywTpJ9S4nk=";
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

    appDir="$out/lib/node_modules/@omdsh-dev/dsh-plugin-check"
    mkdir -p "$appDir"
    cp ${finalAttrs.src}/package.json "$appDir/"
    cp -r cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    packageLock = {
      name = "@omdsh-dev/dsh-plugin-check";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@omdsh-dev/dsh-plugin-check";
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
    description = "Read-only DSH plugin health checker for manifest, patch, build, and registry diagnostics";
    descriptions.zh-CN = "只读检查 DSH 插件清单、补丁、构建与注册状态的健康检查工具";
    homepage = "https://github.com/omdsh-dev/dsh-plugin-check";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
