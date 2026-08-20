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
  version = "0-unstable-2026-08-20";

  src = fetchFromGitHub {
    owner = "vlln";
    repo = "dsh-navbar";
    rev = "e597193bf34bb9655ff3a300c645bd87076db854";
    hash = "sha256-9vCa0y0AJr2SXEZKhRB9JriBWuJERKi3W4mL6LMO+G8=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) pname src postPatch;
    hash = "sha256-KmhGx7SsnvYC4dCWFwn40KsNG1zSYfo//3Oi5cbdCXk=";
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
