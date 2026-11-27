{
  lib,
  bashInteractive,
  buildNpmPackage,
  dshSources,
  fetchPnpmDeps,
  fontconfig,
  jq,
  nodejs,
  nodejs-slim,
  patch,
  pnpmConfigHook,
  pnpmWorkspaceDeploy,
  python3,
  stdenv,
  dsh-system,
  dsh-cua-native,
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
  inherit (dshSources."dsh-workspace") version src;

  __structuredAttrs = true;
  strictDeps = true;
  outputs = [
    "out"
    "cohort"
    "runtime"
    "desktop"
  ];

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
    DSH_CLIENT_COMMIT_HASH = lib.importJSON dshSources.dsh-workspace.artifacts."client-commit.json";
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
  }
  // lib.optionalAttrs cuaIsAvailable {
    # The signed CUA application and its receipt must retain identical bytes.
    stripExclude = "*/DSH Computer Use.app/*";
  }
  // lib.optionalAttrs (isLinux && stdenv.hostPlatform.isAarch64) {
    # Avoid overlapping aggregate TypeScript checks on aarch64 Linux builders.
    DSH_GATE_CONCURRENCY = "1";
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
    cp -r ${dsh-cua-native}/lib/dsh-cua-native/. packages/experimental/cua-macos/
  '';

  preConfigure = ''
    yq -o=json '.overrides // {}' pnpm-workspace.yaml > "$TMPDIR/overrides.json"
    yq -o=json pnpm-lock.yaml > "$TMPDIR/pnpm-lock.json"
    node ${./runtime-importer.mjs} \
      "$TMPDIR/overrides.json" \
      "$TMPDIR/pnpm-lock.json" > "$TMPDIR/runtime-importer.json"
    yq -i '.importers."apps/nix-runtime" = load(strenv(TMPDIR) + "/runtime-importer.json")' pnpm-lock.yaml
  '';

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpmWorkspaceDeploy;
    fetcherVersion = 4;
    hash = dshSources.dsh-workspace.pnpmDepsHash;
  };

  nativeBuildInputs = [
    jq
    nodejs-slim.npm
    pnpmWorkspaceDeploy
    python3
    yq-go
  ]
  ++ lib.optionals isLinux [ patch ];

  npmDeps = null;
  dontNpmInstall = true;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build:official";

  # node-pty's postinstall can't run before deploy assembles the composition.
  preInstall = ''
    pnpm exec tsx scripts/stage-dsh-docs.ts
    pnpm config set --location=project inject-workspace-packages true
    yq -i 'del(.scripts.postinstall)' packages/subprocess/subprocess-local/package.json
  '';

  installPhase = ''
    runHook preInstall

    PNPM_CONFIG_OFFLINE=true PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false \
      pnpm --filter @deepseek-ai/dsh-nix-runtime deploy \
        --prod --config.node-linker=hoisted --config.link-workspace-packages=true \
        "$TMPDIR/dsh-runtime"
    mv "$TMPDIR/dsh-runtime" "$runtime"
    PNPM_CONFIG_OFFLINE=true PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false \
      pnpm --filter @deepseek-ai/dsh-desktop deploy \
        --prod --config.node-linker=hoisted --config.link-workspace-packages=true \
        "$desktop/app"
    cp -r apps/desktop/lib apps/desktop/renderer "$desktop/app/"

    PNPM_CONFIG_OFFLINE=true \
      PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false \
      pnpm run release:pack --family dsh --out "$cohort"

    workspaceDir="$out/lib/dsh-workspace"
    mkdir -p "$workspaceDir"

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

    find "$out" "$runtime" -type f \( -name "config.gypi" -o -name "Makefile" -o -name "*.target.mk" -o -name "binding.Makefile" -o -name "*.o" \) -delete
    find "$out" "$runtime" -depth -type d \( -name ".deps" -o -name "obj.target" \) -exec rm -rf {} +

    runHook postInstall
  '';

  postInstall = lib.optionalString isLinux ''
    patched=0
    while IFS= read -r -d "" dir; do
      patch --no-backup-if-mismatch -d "$dir" -p1 < ${./libreoffice-kit-fontconfig.patch}
      substituteInPlace "$dir/lib/index.js" "$dir/lib/cli.js" \
        --replace-fail '@fc-list@' '${lib.getExe' fontconfig "fc-list"}'
      patched=$((patched + 1))
    done < <(find "$out" "$runtime" "$desktop" -type d -path '*/@deepseek-ai/libreoffice-kit' -print0)
    [ "$patched" -gt 0 ] || {
      printf 'dsh-workspace: @deepseek-ai/libreoffice-kit not found in outputs\n' >&2
      exit 1
    }
  '';

  meta = {
    description = "Built DeepSeek Harness workspace artifacts";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
