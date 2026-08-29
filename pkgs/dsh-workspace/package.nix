{
  lib,
  bashInteractive,
  buildNpmPackage,
  fetchPnpmDeps,
  fetchFromGitHub,
  importPnpmLock,
  jq,
  dshWorkspacePatchHook,
  makeWrapper,
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
  fetchPnpmDeps' = fetchPnpmDeps.override { yq = yq-go; };
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-workspace";
  version = "0.1.2-alpha.1";

  __structuredAttrs = true;
  strictDeps = true;
  outputs = [
    "out"
    "cohort"
    "kernel"
  ];

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    tag = "dsh-v${finalAttrs.version}";
    hash = "sha256-v4XBZN7NN+LodosuIoa3HGUlmrk5dsouTVxJrxPMhlY=";
  };

  env.DSH_CLIENT_COMMIT_HASH = "cd5ef8148158c3a752a658978873241fdf8e2bbc";
  env.PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";

  nodejs = nodejs-slim;
  disallowedReferences = [
    nodejs
    pnpm_11
    python3
  ];

  postPatch = ''
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
  + lib.optionalString (lib.versionOlder pnpm_11.version "11.7.0") ''
    # pnpm < 11.7 cannot parse file: selectors in allowBuilds.
    yq -i '
      .allowBuilds."@deepseek-ai/dsh-subprocess-local" =
        .allowBuilds."@deepseek-ai/dsh-subprocess-local@file:packages/subprocess/subprocess-local" |
      del(.allowBuilds."@deepseek-ai/dsh-subprocess-local@file:packages/subprocess/subprocess-local")
    ' pnpm-workspace.yaml
  ''
  + lib.optionalString (lib.meta.availableOn stdenv.hostPlatform dsh-landlock-run) ''
    install -Dm755 ${dsh-landlock-run}/bin/landlock-run native/landlock-run/packages/${platformKey}/bin/landlock-run
  '';

  preConfigure = "patchDshWorkspace kernel";

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    fetchPnpmDeps = fetchPnpmDeps';
    lockfileJson = ./pnpm-lock.json;
    targetPlatform =
      if stdenv.buildPlatform == stdenv.hostPlatform then stdenv.targetPlatform else null;
    patchedDependencySources = {
      "node-pty@1.2.0-beta.15" = "${finalAttrs.src}/patches/node-pty@1.2.0-beta.15.patch";
    };
  };

  nativeBuildInputs = [
    jq
    makeWrapper
    nodejs-slim.npm
    pnpm_11
    python3
    dshWorkspacePatchHook
    yq-go
  ];

  npmDeps = null;
  dontNpmInstall = true;
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

    PNPM_CONFIG_OFFLINE=true \
      PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false \
      pnpm run release:pack --family dsh --out "$cohort"

    workspaceDir="$out/lib/dsh-workspace"
    appDir="$workspaceDir/kernel"
    kernelApp="$kernel/lib/deepseek-harness"
    mkdir -p "$workspaceDir"

    cp -r apps/cli/lib apps/nix-kernel/lib
    pnpm --filter @deepseek-ai/dsh-nix-kernel deploy \
      --prod \
      --config.node-linker=hoisted \
      --config.link-workspace-packages=true \
      "$appDir"

    cp -r apps/cli/config "$appDir/config"

    rm -f "$appDir/node_modules/node-pty/build/"{{binding.,}Makefile,config.gypi,pty.target.mk}
    sed -i '1{/^#!/d;}' "$appDir/lib/bin.js"
    ${lib.getExe nodejs-slim} "$appDir/node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs"

    mkdir -p "$kernelApp"
    cp -r "$appDir/lib" "$kernelApp/lib"
    cp -r "$appDir/config" "$kernelApp/config"
    cp -r "$appDir/node_modules/@deepseek-ai/dsh-agent-presets/presets" "$kernelApp/config/agent-presets"
    cp "$appDir/package.json" "$kernelApp/package.json"
    # Keep the public kernel self-contained; do not symlink back into the workspace.
    cp -r "$appDir/node_modules" "$kernelApp/node_modules"
    jq '.name = "@deepseek-ai/dsh"' "$kernelApp/package.json" > "$kernelApp/package.json.tmp"
    mv "$kernelApp/package.json.tmp" "$kernelApp/package.json"

    mkdir -p "$kernel/bin"
    makeWrapper ${lib.getExe nodejs-slim} "$kernel/bin/dsh" \
      --add-flags "--expose-internals" \
      --add-flags "$kernelApp/lib/bin.js"

    runtimeBundlesDir="$workspaceDir/runtime-bundles"
    for packageJson in packages/*/*/package.json; do
      [ -f "$packageJson" ] || continue
      bundlePatchTag=$(yq -r '.dsh.bundle.patch | tag' "$packageJson")
      case "$bundlePatchTag" in
        "!!null")
          continue
          ;;
        "!!str")
          bundlePatch=$(yq -r '.dsh.bundle.patch' "$packageJson")
          ;;
        *)
          printf 'dsh-workspace: bundle patch must be a string: %s\n' "$packageJson" >&2
          exit 1
          ;;
      esac

      packageName=$(yq -r '.name // ""' "$packageJson")
      [ -n "$packageName" ] || {
        printf 'dsh-workspace: bundle package has no name: %s\n' "$packageJson" >&2
        exit 1
      }
      [ -n "$bundlePatch" ] || {
        printf 'dsh-workspace: bundle patch is empty: %s\n' "$packageJson" >&2
        exit 1
      }

      bundleDir="$runtimeBundlesDir/$packageName"
      mkdir -p "$(dirname "$bundleDir")"
      pnpm --filter "$packageName" deploy \
        --prod \
        --config.node-linker=hoisted \
        --config.link-workspace-packages=true \
        "$bundleDir"

      for artifact in package.json "$bundlePatch" lib; do
        [ -e "$bundleDir/$artifact" ] || {
          printf 'dsh-workspace: deployed bundle artifact is missing: %s\n' "$bundleDir/$artifact" >&2
          exit 1
        }
      done
    done

    # External bundles may need client packages that are build-time peers of
    # the CLI kernel without adding them to the kernel runtime closure.
    for clientPackage in ui-commands ui-slots; do
      clientPackagesDir="$workspaceDir/client-packages/@deepseek-ai/dsh-client-$clientPackage"
      mkdir -p "$clientPackagesDir"
      cp "packages/client/$clientPackage/package.json" "$clientPackagesDir/package.json"
      cp -r "packages/client/$clientPackage/lib" "$clientPackagesDir/lib"
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
