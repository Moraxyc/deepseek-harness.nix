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
  pname = "dsh-navbar";
  version = "0.4.0-unstable-2026-09-10";

  src = fetchFromGitHub {
    owner = "vlln";
    repo = "dsh-navbar";
    rev = "e53adfc8c837ebcb4b6a52c2c4baf7cb6e8b795e";
    hash = "sha256-aopZU/ey/i+fflOVmIqtoL003Subc42z+U2OZPcboso=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) pname src postPatch;
    hash = "sha256-/UxceshohMi2MvIq+QVFKg7LEb8kgykfYc/mqmy3H9A=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  linkKernelNodeModules = dsh-kernel;

  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@vlln/dsh-navbar"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  passthru = {
    requiresWeb = true;
    packageLock = {
      name = "@vlln/dsh-navbar";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@vlln/dsh-navbar";
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
    description = "Conversation node navigation rail for the DSH web UI";
    descriptions.zh-CN = "DSH Web 界面的对话节点导航条";
    homepage = "https://github.com/vlln/dsh-navbar";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
