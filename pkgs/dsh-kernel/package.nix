{
  lib,
  buildNpmPackage,
  dsh-src,
  fetchPnpmDeps,
  jq,
  makeWrapper,
  nodejs,
  nodejs-slim,
  pnpmConfigHook,
  pnpm_11,
  python3,
  versionCheckHook,
  yq-go,
}:

let
  dropBundles = ''
    with_entries(select(
      .key != "@deepseek-ai/dsh-base" and
      .key != "@deepseek-ai/dsh-headless" and
      .key != "@deepseek-ai/dsh-web-app"
    ))
  '';
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-kernel";
  version = (lib.importJSON "${dsh-src}/package.json").version;

  src = dsh-src;

  nodejs = nodejs-slim;
  disallowedReferences = [ nodejs ];

  postPatch = ''
    workspaceDeps="$TMPDIR/dsh-workspace-dependencies.json"
    workspaceLockDeps="$TMPDIR/dsh-workspace-lock-dependencies.json"
    yq ea -o=json -I=0 \
      '(select(.name | test("^@deepseek-ai/")) | {
        (.name): "workspace:^"
      }) as $item ireduce ({}; . * $item)' \
      vendor/group/package.json packages/*/*/package.json > "$workspaceDeps"
    yq ea -o=json -I=0 \
      '(select(.name | test("^@deepseek-ai/")) | {
        (.name): {
          "specifier": "workspace:^",
          "version": "link:" + (filename | sub("/package.json$", "") | sub("^", "../../"))
        }
      }) as $item ireduce ({}; . * $item)' \
      vendor/group/package.json packages/*/*/package.json > "$workspaceLockDeps"
    DEPS_FILE="$workspaceDeps" yq -i \
      '.dependencies *= load(strenv(DEPS_FILE))' apps/cli/package.json
    DEPS_FILE="$workspaceLockDeps" yq -i \
      '.importers."apps/cli".dependencies *= load(strenv(DEPS_FILE))' pnpm-lock.yaml
  '';

  preConfigure = ''
    mkdir apps/nix-composition
    cp apps/cli/package.json apps/nix-composition/package.json

    yq -i '
      .name = "@deepseek-ai/dsh-nix-composition" |
      del(.devDependencies) |
      .dependencies |= ${dropBundles}
    ' apps/nix-composition/package.json
    yq -i '
      .importers."apps/nix-composition".dependencies =
        (.importers."apps/cli".dependencies | ${dropBundles})
    ' pnpm-lock.yaml
  '';

  # The patch uses mikefarah yq's `ea`, not the Python jq wrapper default.
  pnpmDeps = (fetchPnpmDeps.override { yq = yq-go; }) {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-tlxGBb/Mp8dFRMYM9Hhk2fHsj/5EA8AoWBBXNnRl0CE=";
  };

  nativeBuildInputs = [
    jq
    makeWrapper
    nodejs-slim.npm
    pnpm_11
    python3
    yq-go
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  # node-pty's postinstall can't run before deploy assembles the composition
  preInstall = ''
    pnpm config set --location=project inject-workspace-packages true
    yq -i 'del(.scripts.postinstall)' packages/subprocess/subprocess-local/package.json
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/deepseek-harness"

    cp -r apps/cli/lib apps/nix-composition/lib
    cp -r apps/cli/config apps/nix-composition/config
    pnpm --filter @deepseek-ai/dsh-nix-composition deploy \
      --prod \
      --config.node-linker=hoisted \
      --config.link-workspace-packages=true \
      "$appDir"
    yq -i '.name = "@deepseek-ai/dsh"' "$appDir/package.json"

    # Prune
    rm -f "$appDir/node_modules/node-pty/build/"{{binding.,}Makefile,config.gypi,pty.target.mk}
    sed -i '1{/^#!/d;}' "$appDir/lib/bin.js"

    ${lib.getExe nodejs-slim} "$appDir/node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs"

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs-slim} $out/bin/dsh \
      --add-flags "--expose-internals" \
      --add-flags "$appDir/lib/bin.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    dshBundles = [ ];
  };

  meta = {
    description = "dsh kernel without profile bundles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
})
