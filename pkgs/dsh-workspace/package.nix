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
  stdenv,
  dsh-landlock-run ? null,
  yq-go,
}:

let
  platformKey = with stdenv.hostPlatform.node; "${platform}-${arch}";
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-workspace";
  version = "0.1.0-rc.8";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    tag = "dsh-v${finalAttrs.version}";
    hash = "sha256-FzToX43k6upXkwTxTYXHRK5IdatxibxeZgZBpuDE7S4=";
  };

  env.DSH_CLIENT_COMMIT_HASH = "141eb6fef83422698aef7a981029e843e8161534";

  nodejs = nodejs-slim;
  disallowedReferences = [
    nodejs
    pnpm_11
    python3
  ];

  postPatch = ''
    patchDshWorkspace dependencies

    substituteInPlace "packages/terminal/terminal-bash/src/config.ts" \
      --replace-fail \
      "export const DEFAULT_BASH_SHELL = '/bin/bash'" \
      "export const DEFAULT_BASH_SHELL = '${lib.getExe bashInteractive}'"

    substituteInPlace packages/client/tsdown.client.ts \
      --replace-fail \
      "return CSS_VIRTUAL_PREFIX + abs + CSS_VIRTUAL_SUFFIX" \
      "return CSS_VIRTUAL_PREFIX + relative(process.cwd(), abs) + CSS_VIRTUAL_SUFFIX" \
      --replace-fail \
      "const fileId = virtualId.slice(CSS_VIRTUAL_PREFIX.length, -CSS_VIRTUAL_SUFFIX.length)" \
      "const fileId = resolvePath(process.cwd(), virtualId.slice(CSS_VIRTUAL_PREFIX.length, -CSS_VIRTUAL_SUFFIX.length))" \
      --replace-fail \
      "Object.entries(cssExports ?? {})" \
      "Object.entries(cssExports ?? {}).sort(([a], [b]) => a.localeCompare(b))"
  ''
  + lib.optionalString (lib.meta.availableOn stdenv.hostPlatform dsh-landlock-run) ''
    install -Dm755 ${dsh-landlock-run}/bin/landlock-run native/landlock-run/packages/${platformKey}/bin/landlock-run
  '';

  preConfigure = "patchDshWorkspace composition";

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

    mkdir -p "$workspaceDir/frontends/web"
    cp apps/web/package.json "$workspaceDir/frontends/web/package.json"
    cp -r apps/web/dist "$workspaceDir/frontends/web/dist"

    runHook postInstall
  '';

  passthru = {
    # Used by the update script to compare against importPnpmLock.
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
