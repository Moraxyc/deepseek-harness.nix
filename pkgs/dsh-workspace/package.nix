{
  codex,
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
  dsh-landlock-run,
  yq-go,
}:

let
  platformKey = with stdenv.hostPlatform.node; "${platform}-${arch}";
  pnpmLock = builtins.fromJSON (builtins.readFile ./pnpm-lock.json);
  codexVersion =
    pnpmLock.importers."packages/subagent/subagent-codex".dependencies."@openai/codex".specifier;
  codexPlatformPackage = "@openai/codex-${platformKey}";
  codexPlatformVersion = "${codexVersion}-${platformKey}";
  codexPlatformDependency = {
    specifier = "npm:@openai/codex@${codexPlatformVersion}";
    version = "@openai/codex@${codexPlatformVersion}";
  };
  fetchPnpmDeps' = fetchPnpmDeps.override { yq = yq-go; };
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-workspace";
  version = "0.1.1-rc.2";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    tag = "dsh-v${finalAttrs.version}";
    hash = "sha256-rrjXoyccTxKIbZ00Z4Vy7EA9tGZ15WUqLBFnZSgw1YE=";
  };

  env.DSH_CLIENT_COMMIT_HASH = "b150a551b8d465e31e418e1b2eaf5e79bbb7d28e";

  nodejs = nodejs-slim;
  disallowedReferences = [
    nodejs
    pnpm_11
    python3
  ];

  postPatch = ''
    DSH_CODEX_PLATFORM_KEY=${lib.escapeShellArg platformKey} patchDshWorkspace dependencies

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
    fetchPnpmDeps = fetchPnpmDeps';
    lockfileJson = ./pnpm-lock.json;
    importerDependencyOverrides = {
      "packages/subagent/subagent-codex" = {
        "${codexPlatformPackage}" = codexPlatformDependency;
      };
    };
    targetPlatform =
      if stdenv.buildPlatform == stdenv.hostPlatform then stdenv.targetPlatform else null;
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
  npmInstallFlags = finalAttrs.pnpmDeps.passthru.pnpmInstallFlags;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build:official";

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

    providerRoot="$workspaceDir/providers"
    mkdir -p "$providerRoot"
    while IFS= read -r providerPackage; do
      [ -n "$providerPackage" ] || continue
      providerName="''${providerPackage#@deepseek-ai/dsh-}"
      providerDir="$providerRoot/$providerName"
      pnpm --filter "$providerPackage" deploy \
        --prod \
        --config.node-linker=hoisted \
        --config.link-workspace-packages=true \
        "$providerDir"
      if [ "$providerPackage" = '@deepseek-ai/dsh-subagent-codex' ]; then
        codexPlatformPackage="@openai/codex-${platformKey}"
        if [ ! -d "$providerDir/node_modules/$codexPlatformPackage" ]; then
          codexPlatformSource="node_modules/$codexPlatformPackage"
          [ -d "$codexPlatformSource" ] || {
            printf 'dsh-workspace: Codex platform package is missing: %s\n' "$codexPlatformSource" >&2
            exit 1
          }
          mkdir -p "$providerDir/node_modules/@openai"
          cp -rL "$codexPlatformSource" "$providerDir/node_modules/@openai/"
        fi
        codexPlatformRoot="$providerDir/node_modules/$codexPlatformPackage"
        codexBinaryCount=0
        for codexBinary in \
          "$codexPlatformRoot"/vendor/*/bin/codex \
          "$codexPlatformRoot"/vendor/*/bin/codex-code-mode-host
        do
          if [ -e "$codexBinary" ] || [ -L "$codexBinary" ]; then
            codexBinaryCount=$((codexBinaryCount + 1))
            rm -f "$codexBinary"
            case "$(basename "$codexBinary")" in
              codex)
                ln -s ${lib.getExe codex} "$codexBinary"
                ;;
              codex-code-mode-host)
                ln -s ${lib.getExe' codex "codex-code-mode-host"} "$codexBinary"
                ;;
            esac
          fi
        done
        [ "$codexBinaryCount" -gt 0 ] || {
          printf 'dsh-workspace: Codex platform payload has no vendor binaries: %s\n' "$codexPlatformRoot" >&2
          exit 1
        }
      fi
      for artifact in package.json cordis.patch.yml lib node_modules; do
        [ -e "$providerDir/$artifact" ] || {
          printf 'dsh-workspace: provider artifact is missing: %s\n' "$providerDir/$artifact" >&2
          exit 1
        }
      done
    done < <(dshWorkspaceOptionalProviderNames)

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
    fetchPnpmDeps = finalAttrs.pnpmDeps.passthru.fetchPnpmDeps;

    updateScript = ./update.sh;
  };

  meta = {
    description = "Built DeepSeek Harness workspace artifacts";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
