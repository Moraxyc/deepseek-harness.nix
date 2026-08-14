{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
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
  version = "0.1.0-rc.5";

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    rev = "47f943859bef60e4160492346772ded9b24f765a";
    hash = "sha256-ZPGCNoPXVjP76Tm/tFPDX2X95cd83M4iHLmVP5dR+Ps=";
  };

  nodejs = nodejs-slim;
  disallowedReferences = [ nodejs ];

  postPatch = "patchDshWorkspace dependencies";
  preConfigure = "patchDshWorkspace composition";

  pnpmDeps = (fetchPnpmDeps.override { yq = yq-go; }) {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    nativeBuildInputs = [ dshWorkspacePatchHook ];
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-+dkclQcDhAmHmB6dM8bffc3pMrivJR1T1wi/56IgQro=";
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

  meta = {
    description = "Built DeepSeek Harness workspace artifacts";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
