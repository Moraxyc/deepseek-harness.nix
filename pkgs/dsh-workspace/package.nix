{
  lib,
  bashInteractive,
  buildNpmPackage,
  fetchFromGitHub,
  importPnpmLock,
  jq,
  dshWorkspacePatchHook,
  makeWrapper,
  nodejs,
  nodejs-slim,
  pnpmConfigHook,
  pnpmWorkspaceDeploy,
  python3,
  stdenv,
  dsh-system,
  writers,
  yq-go,
}:

let
  platformKey = with stdenv.hostPlatform.node; "${platform}-${arch}";
  dshSystemIsAvailable = lib.meta.availableOn stdenv.hostPlatform dsh-system;
  inherit (stdenv.hostPlatform) isLinux isDarwin;
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-workspace";
  version = "0.1.6-alpha.2";

  __structuredAttrs = true;
  strictDeps = true;
  outputs = [
    "out"
    "cohort"
    "kernel"
    "desktop"
  ];

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    tag = "dsh-v${finalAttrs.version}";
    hash = "sha256-zoO7+AFR5KiNgmA+4agclQm7oPiE+T0WgMCM0j4Vcdw=";
  };

  patches = [
    ./desktop-nix-profile.patch
    # The upstream manifest omitted Linux even though its POSIX dependency
    # layout is supported by the runtime resolver.
    ./desktop-linux-primary-runtime.patch
    # Nix carries the primary runtime in the application resources; use it
    # directly instead of copying it into the user's Harness home.
    ./desktop-bundled-primary-runtime.patch
    # The prebuilt require-builtin addon only accepts upstream Electron builds, so
    # the desktop host reads Node internals through `--expose-internals` instead.
    ./expose-internals-loader.patch
    # Client CSS virtual ids would otherwise carry the build directory, and the
    # module export map arrives in hash order; the patch rebases ids onto the
    # build cwd and sorts the export map behind the injected class map.
    ./client-bundle-determinism.patch
  ];

  env = {
    DSH_CLIENT_COMMIT_HASH = "ddefc45fbc7f8e46dd73185e68295696d1297887";
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
    # Rendered at evaluation time so the workspace patch hook does not have to
    # re-parse pnpm-workspace.yaml in the build sandbox.
    DSH_WORKSPACE_OVERRIDES = "${writers.writeJSON "dsh-workspace-overrides.json" (
      finalAttrs.pnpmDeps.passthru.workspaceConfig.overrides or { }
    )}";
  };

  nodejs = nodejs-slim;
  disallowedReferences = [
    nodejs
    pnpmWorkspaceDeploy
    python3
  ];

  postPatch = ''
    substituteInPlace "packages/terminal/terminal-bash/src/config.ts" \
      --replace-fail \
      "export const DEFAULT_BASH_SHELL = '/bin/bash'" \
      "export const DEFAULT_BASH_SHELL = '${lib.getExe bashInteractive}'"
  ''
  + lib.optionalString (dshSystemIsAvailable && isLinux) ''
    install -Dm755 ${dsh-system}/bin/landlock-run native/system/packages/${platformKey}/bin/landlock-run
    install -Dm644 ${dsh-system}/bin/glibc/system.node native/system/packages/${platformKey}/bin/glibc/system.node
    install -Dm644 ${dsh-system}/bin/musl/system.node native/system/packages/${platformKey}/bin/musl/system.node
  ''
  + lib.optionalString (dshSystemIsAvailable && isDarwin) ''
    install -Dm644 ${dsh-system}/bin/system.node native/system/packages/${platformKey}/bin/system.node
  '';

  preConfigure = "patchDshWorkspace kernel";

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpmWorkspaceDeploy;
    lockfileJson = ./pnpm-lock.json;
    workspaceJson = lib.importJSON ./pnpm-workspace.json;
    workspaceRoot = finalAttrs.src;
    targetPlatform =
      if stdenv.buildPlatform == stdenv.hostPlatform then stdenv.targetPlatform else null;
  };

  nativeBuildInputs = [
    jq
    makeWrapper
    nodejs-slim.npm
    pnpmWorkspaceDeploy
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

    PNPM_CONFIG_OFFLINE=true PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false \
      pnpm --filter @deepseek-ai/dsh-desktop-host deploy \
        --prod --config.node-linker=hoisted --config.link-workspace-packages=true \
        "$desktop/host"
    PNPM_CONFIG_OFFLINE=true PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false \
      pnpm --filter @deepseek-ai/dsh-desktop deploy \
        --prod --config.node-linker=hoisted --config.link-workspace-packages=true \
        "$desktop/app"
    cp -r apps/desktop/lib apps/desktop/renderer "$desktop/app/"

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

    find "$appDir/node_modules" -type f \( -name "config.gypi" -o -name "Makefile" -o -name "*.target.mk" -o -name "binding.Makefile" -o -name "*.o" \) -delete
    find "$appDir/node_modules" -depth -type d \( -name ".deps" -o -name "obj.target" \) -exec rm -rf {} +
    sed -i '1{/^#!/d;}' "$appDir/lib/bin.js"
    ${lib.getExe nodejs-slim} "$appDir/node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs"

    mkdir -p "$kernelApp"
    cp -r "$appDir/lib" "$kernelApp/lib"
    cp -r "$appDir/config" "$kernelApp/config"
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
      bundlePatches=()
      case "$bundlePatchTag" in
        "!!null")
          continue
          ;;
        "!!str")
          bundlePatches+=("$(yq -r '.dsh.bundle.patch' "$packageJson")")
          ;;
        "!!seq")
          bundlePatchCount=$(yq -r '.dsh.bundle.patch | length' "$packageJson")
          [ "$bundlePatchCount" -gt 0 ] || {
            printf 'dsh-workspace: bundle patch array is empty: %s\n' "$packageJson" >&2
            exit 1
          }
          for ((bundlePatchIndex = 0; bundlePatchIndex < bundlePatchCount; bundlePatchIndex++)); do
            bundlePatchItemTag=$(yq -r ".dsh.bundle.patch[$bundlePatchIndex] | tag" "$packageJson")
            [ "$bundlePatchItemTag" = "!!str" ] || {
              printf 'dsh-workspace: bundle patch array entry must be a string: %s[%s]\n' "$packageJson" "$bundlePatchIndex" >&2
              exit 1
            }
            bundlePatches+=("$(yq -r ".dsh.bundle.patch[$bundlePatchIndex]" "$packageJson")")
          done
          ;;
        *)
          printf 'dsh-workspace: bundle patch must be a string or array: %s\n' "$packageJson" >&2
          exit 1
          ;;
      esac

      packageName=$(yq -r '.name // ""' "$packageJson")
      [ -n "$packageName" ] || {
        printf 'dsh-workspace: bundle package has no name: %s\n' "$packageJson" >&2
        exit 1
      }
      [ "''${#bundlePatches[@]}" -gt 0 ] || {
        printf 'dsh-workspace: bundle patch is missing: %s\n' "$packageJson" >&2
        exit 1
      }

      bundleDir="$runtimeBundlesDir/$packageName"
      mkdir -p "$(dirname "$bundleDir")"
      pnpm --filter "$packageName" deploy \
        --prod \
        --config.node-linker=hoisted \
        --config.link-workspace-packages=true \
        "$bundleDir"

      for artifact in package.json lib; do
        [ -e "$bundleDir/$artifact" ] || {
          printf 'dsh-workspace: deployed bundle artifact is missing: %s\n' "$bundleDir/$artifact" >&2
          exit 1
        }
      done
      for bundlePatch in "''${bundlePatches[@]}"; do
        case "$bundlePatch" in
          ./*)
            ;;
          *)
            printf "dsh-workspace: bundle patch must be a relative './...' path: %s\n" "$packageJson" >&2
            exit 1
            ;;
        esac
        case "$bundlePatch" in
          *\\*)
            printf 'dsh-workspace: bundle patch must not contain backslashes: %s\n' "$packageJson" >&2
            exit 1
            ;;
        esac
        [ -n "''${bundlePatch#./}" ] || {
          printf 'dsh-workspace: bundle patch is empty: %s\n' "$packageJson" >&2
          exit 1
        }
        [ -f "$bundleDir/''${bundlePatch#./}" ] || {
          printf 'dsh-workspace: deployed bundle patch is missing: %s\n' "$bundleDir/''${bundlePatch#./}" >&2
          exit 1
        }
      done
    done

    mkdir -p "$workspaceDir/frontends/web"
    cp apps/web/package.json "$workspaceDir/frontends/web/package.json"
    cp -r apps/web/dist "$workspaceDir/frontends/web/dist"

    find "$out" "$kernel" -type f \( -name "config.gypi" -o -name "Makefile" -o -name "*.target.mk" -o -name "binding.Makefile" -o -name "*.o" \) -delete
    find "$out" "$kernel" -depth -type d \( -name ".deps" -o -name "obj.target" \) -exec rm -rf {} +

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
