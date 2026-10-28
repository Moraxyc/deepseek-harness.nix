{
  lib,
  bashInteractive,
  buildNpmPackage,
  fetchFromGitHub,
  fontconfig,
  importPnpmLock,
  jq,
  dshWorkspacePatchHook,
  makeWrapper,
  nodejs,
  nodejs-slim,
  patch,
  pnpmConfigHook,
  pnpmWorkspaceDeploy,
  python3,
  runCommand,
  stdenv,
  dsh-system,
  dsh-cua-native,
  writers,
  yq-go,
}:

let
  platformKey = with stdenv.hostPlatform.node; "${platform}-${arch}";
  dshSystemIsAvailable = lib.meta.availableOn stdenv.hostPlatform dsh-system;
  cuaIsAvailable = lib.meta.availableOn stdenv.hostPlatform dsh-cua-native;
  inherit (stdenv.hostPlatform) isLinux isDarwin;
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-workspace";
  version = "0.2.2-alpha.2";

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
    hash = "sha256-KxEyrXuFwEKXney6ngmuEMp1djxPJ0F6duVZgBJ+fI0=";
  };

  patches = [
    ./desktop-nix-profile.patch
    # The prebuilt require-builtin addon only accepts upstream Electron builds.
    ./expose-internals-loader.patch
    # Absolute CSS IDs make client bundles depend on the build directory.
    ./client-bundle-determinism.patch
    # On Linux, login-shell discovery replaces the wrapper PATH and hides bundled runtimes.
    ./desktop-login-shell-macos-only.patch
    ./desktop-signal-shutdown.patch
  ];

  env = {
    DSH_CLIENT_COMMIT_HASH = "f3803c96974ad4a94195fb97e5c637e9c2a3afe3";
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
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
  ''
  + lib.optionalString cuaIsAvailable ''
    install -Dm755 ${dsh-cua-native}/bin/dsh-cua-native \
      packages/experimental/cua-macos/native/bin/${platformKey}/dsh-cua-native
  '';

  preConfigure = ''
    patchDshWorkspace kernel
  ''
  + lib.optionalString isLinux ''
    # Match the patched tarball used to populate the offline dependency store.
    yq -i '
      .packages."@deepseek-ai/libreoffice-kit@0.1.5".resolution = load("${
        writers.writeJSON "libreoffice-kit-resolution.json"
          finalAttrs.pnpmDeps.passthru.rewrittenLockfileData.packages."@deepseek-ai/libreoffice-kit@0.1.5".resolution
      }")
    ' pnpm-lock.yaml
  '';

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpmWorkspaceDeploy;
    lockfileJson = ./pnpm-lock.json;
    workspaceJson = lib.importJSON ./pnpm-workspace.json;
    workspaceRoot = finalAttrs.src;
    packageSourceOverrides = lib.optionalAttrs isLinux {
      "@deepseek-ai/libreoffice-kit@0.1.5" =
        { previousSource, ... }:
        runCommand "libreoffice-kit-0.1.5-fontconfig.tgz"
          {
            src = previousSource;
            nativeBuildInputs = [ patch ];
          }
          ''
            tar -xzf "$src"
            patch -d package -p1 < ${./libreoffice-kit-fontconfig.patch}
            substituteInPlace package/lib/index.js package/lib/cli.js \
              --replace-fail '@fc-list@' '${lib.getExe' fontconfig "fc-list"}'
            tar --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner \
              -czf "$out" package
          '';
    };
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
    # Copy dependencies because the public kernel must run without the workspace.
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
