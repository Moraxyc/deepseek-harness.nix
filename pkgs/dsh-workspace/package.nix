{
  lib,
  bashInteractive,
  buildNpmPackage,
  fetchPnpmDeps,
  fetchFromGitHub,
  importPnpmLock,
  dshWorkspacePatchHook,
  jq,
  nodejs,
  nodejs-slim,
  pnpmConfigHook,
  pnpm_11,
  python3,
  yq-go,
}:

buildNpmPackage (finalAttrs: {
  pname = "dsh-workspace";
  version = "dsh-v0.1.0-rc.7-unstable-2026-08-17";

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    rev = "99f6f02fecdb7dff40c3fbc9470f5907c29f74ca";
    hash = "sha256-xPP8FB308n8SD5B65whaErLyaDBbFferoQ9g3H6h2es=";
  };

  nodejs = nodejs-slim;
  disallowedReferences = [
    nodejs
    pnpm_11
    python3
  ];

  postPatch = "patchDshWorkspace dependencies";
  preConfigure = "patchDshWorkspace composition";

  # pnpmDeps = (fetchPnpmDeps.override { yq = yq-go; }) {
  #   inherit (finalAttrs)
  #     pname
  #     version
  #     src
  #     postPatch
  #     ;
  #   nativeBuildInputs = [ dshWorkspacePatchHook ];
  #   pnpm = pnpm_11;
  #   fetcherVersion = 4;
  #   hash = "sha256-zmlWt5HYvzkCnCDD5X/psgfGPbRAUwO0p4qDtI5+R5M=";
  # };

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    lockfileJson = ./pnpm-lock.json;
    patchedDependencySources = {
      "node-pty@1.2.0-beta.15" = "${finalAttrs.src}/patches/node-pty@1.2.0-beta.15.patch";
    };
  };

  nativeBuildInputs = [
    jq
    nodejs-slim.npm
    pnpm_11
    python3
    dshWorkspacePatchHook
    yq-go
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  # node-pty's postinstall can't run before deploy assembles the composition.
  preInstall = ''
    pnpm config set --location=project inject-workspace-packages true
    yq -i 'del(.scripts.postinstall)' packages/subprocess/subprocess-local/package.json
  '';

  installPhase = ''
    runHook preInstall

    workspaceDir="$out/lib/dsh-workspace"
    appDir="$workspaceDir/kernel"
    mkdir -p "$workspaceDir"

    cp -r apps/cli/lib apps/nix-composition/lib
    cp -r apps/cli/config apps/nix-composition/config
    pnpm --filter @deepseek-ai/dsh-nix-composition deploy \
      --prod \
      --config.node-linker=hoisted \
      --config.link-workspace-packages=true \
      "$appDir"
    yq -i '.name = "@deepseek-ai/dsh-nix-composition"' "$appDir/package.json"

    substituteInPlace "$appDir/node_modules/@deepseek-ai/dsh-terminal-bash/lib/index.js" \
      --replace-fail '"/bin/bash"' '"${lib.getExe bashInteractive}"'

    # Keep only the runtime artifacts needed by the kernel and bundle packages.
    rm -rf "$appDir/node_modules/@anthropic-ai/claude-agent-sdk-"*
    jq 'del(.optionalDependencies)' \
      "$appDir/node_modules/@anthropic-ai/claude-agent-sdk/package.json" \
      > "$appDir/node_modules/@anthropic-ai/claude-agent-sdk/package.json.tmp"
    mv "$appDir/node_modules/@anthropic-ai/claude-agent-sdk/package.json.tmp" \
      "$appDir/node_modules/@anthropic-ai/claude-agent-sdk/package.json"
    rm -f "$appDir/node_modules/node-pty/build/"{{binding.,}Makefile,config.gypi,pty.target.mk}
    sed -i '1{/^#!/d;}' "$appDir/lib/bin.js"
    ${lib.getExe nodejs-slim} "$appDir/node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs"

    for bundle in packages/bundle/*; do
      [ -d "$bundle" ] || continue
      bundleName=$(basename "$bundle")
      bundleDir="$workspaceDir/bundles/$bundleName"
      mkdir -p "$bundleDir"
      for artifact in package.json cordis.patch.yml lib; do
        [ -e "$bundle/$artifact" ] || {
          printf 'dsh-workspace: bundle artifact is missing: %s\n' "$bundle/$artifact" >&2
          exit 1
        }
        cp -r "$bundle/$artifact" "$bundleDir/$artifact"
      done
    done

    [ -f apps/web/package.json ] || {
      printf 'dsh-workspace: web frontend package.json is missing\n' >&2
      exit 1
    }
    [ -d apps/web/dist ] || {
      printf 'dsh-workspace: web frontend dist is missing\n' >&2
      exit 1
    }
    mkdir -p "$workspaceDir/frontends/web"
    cp apps/web/package.json "$workspaceDir/frontends/web/package.json"
    cp -r apps/web/dist "$workspaceDir/frontends/web/dist"

    runHook postInstall
  '';

  passthru = {
    fetchPnpmDeps = (fetchPnpmDeps.override { yq = yq-go; }) {
      inherit (finalAttrs)
        pname
        version
        src
        postPatch
        ;
      nativeBuildInputs = [ dshWorkspacePatchHook ];
      pnpm = pnpm_11;
      fetcherVersion = 4;
      hash = "";
    };

    updateScript = ./update.sh;
  };

  meta = {
    description = "Built DeepSeek Harness workspace artifacts";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
