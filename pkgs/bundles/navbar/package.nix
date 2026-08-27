{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  jq,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-navbar";
  version = "0.4.0-unstable-2026-08-27";

  src = fetchFromGitHub {
    owner = "vlln";
    repo = "dsh-navbar";
    rev = "502253836f49bf73d55f1d525bd191b1b1c27c38";
    hash = "sha256-0vuB6wTepqmr2HdocBx1l7QjCXXmy+hEBzpyQBHZgrE=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) pname src postPatch;
    hash = "sha256-s7OO0nW1g0xZPo9TCSPqNH7v8mGvvFCFaByClD73ZFI=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  linkKernelNodeModules = dsh-kernel;

  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cat > package-lock.json <<'JSON'
    {
      "name": "@vlln/dsh-navbar",
      "version": "${finalAttrs.version}",
      "lockfileVersion": 3,
      "requires": true,
      "packages": {
        "": {
          "name": "@vlln/dsh-navbar",
          "version": "${finalAttrs.version}"
        }
      }
    }
    JSON
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

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Conversation node navigation rail for the DSH web UI";
    descriptions.zh-CN = "DSH Web 界面的对话节点导航条";
    homepage = "https://github.com/vlln/dsh-navbar";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
