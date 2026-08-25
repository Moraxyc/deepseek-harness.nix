{
  lib,
  buildNpmPackage,
  jq,
  nodejs,
  nodejs-slim,
  pnpm_11,
  stdenvNoCC,
  writeShellApplication,
}:

let
  resolveDshBundles = ../lib/resolve-dsh-bundles.mjs;

  # Shared protocol required by the composition layer for every bundle.
  protocol =
    {
      runtimeDeps ? [ ],
    }:
    {
      dshBundle = true;
      dshBundleHelper = "buildDshBundle";
      inherit runtimeDeps;
    };

  # Fail early when a package does not implement the public bundle contract.
  validateProtocol =
    {
      runtimeDeps,
    }:
    assert lib.isList runtimeDeps;
    protocol { inherit runtimeDeps; };

  dshBundleResolver = writeShellApplication {
    name = "dsh-resolve-bundles";
    runtimeInputs = [ nodejs-slim ];
    text = ''
      exec ${lib.getExe nodejs-slim} ${resolveDshBundles} "$@"
    '';
  };

  validateInstalledBundle = ''
    bundleRoot="$out/lib/node_modules"
    [ -d "$bundleRoot" ] || {
      printf 'buildDshBundle: expected bundle output directory %s\\n' "$bundleRoot" >&2
      exit 1
    }
    mkdir -p "$out/nix-support"
    ${lib.getExe dshBundleResolver} manifest \
      "$out/nix-support/dsh-bundles.json" \
      "$bundleRoot"
  '';

  suppressChildBundlePatches = ''
    suppress_patch() {
      [ -f "$1/cordis.patch.yml" ] || return 0
      [ "$1" = "$deployPackagePath" ] && return 0
      printf '[]\n' > "$1/cordis.patch.yml"
    }
    for entry in "$out"/lib/node_modules/*; do
      [ -d "$entry" ] || continue
      case "$(basename "$entry")" in
        .*)
          continue
          ;;
        @*)
          for pkg in "$entry"/*; do
            [ -d "$pkg" ] || continue
            suppress_patch "$pkg"
          done
          ;;
        *)
          suppress_patch "$entry"
          ;;
      esac
    done
  '';

  linkKernelNodeModulesScript = kernel: keep: ''
    kernelNodeModules="${kernel}/lib/deepseek-harness/node_modules"
    [ -d "$kernelNodeModules" ] || {
      printf 'buildDshBundle: kernel node_modules is missing: %s\n' "$kernelNodeModules" >&2
      exit 1
    }

    reservedList="$TMPDIR/dsh-kernel-reserved.txt"
    : > "$reservedList"
    for entry in "$kernelNodeModules"/*; do
      [ -d "$entry" ] || continue
      case "$(basename "$entry")" in
        @*)
          for package in "$entry"/*; do
            [ -d "$package" ] || continue
            printf '%s\n' "$(basename "$entry")/$(basename "$package")" >> "$reservedList"
          done
          ;;
        *)
          printf '%s\n' "$(basename "$entry")" >> "$reservedList"
          ;;
      esac
    done

    keepList="$TMPDIR/dsh-kernel-keep.txt"
    : > "$keepList"
    ${lib.concatMapStringsSep "\n" (
      package: "printf '%s\\n' ${lib.escapeShellArg package} >> \"$keepList\""
    ) keep}

    bundleNodeModules="$out/lib/node_modules"
    [ -d "$bundleNodeModules" ] || {
      printf 'buildDshBundle: bundle node_modules is missing: %s\n' "$bundleNodeModules" >&2
      exit 1
    }

    is_kernel_peer_kept() {
      local candidate=$1 item
      while IFS= read -r item; do
        [ -n "$item" ] || continue
        [ "$item" = "$candidate" ] && return 0
      done < "$keepList"
      return 1
    }

    # The kernel owns every package present in its node_modules. Bundle-local
    # copies of those names must not survive into the final composition,
    # otherwise the same runtime package can resolve twice. Callers can keep a
    # specific local copy through linkKernelNodeModulesKeep.
    while IFS= read -r reserved; do
      [ -n "$reserved" ] || continue
      is_kernel_peer_kept "$reserved" && continue
      rm -rf "$bundleNodeModules/$reserved"
      find "$bundleNodeModules" \
        -depth \
        \( -type d -o -type l \) \
        -path "*/node_modules/$reserved" \
      -exec rm -rf {} + 2>/dev/null || true
    done < "$reservedList"

    # Removing package directories can leave dangling .bin links behind.
    # noBrokenSymlinks rejects those, so delete any symlink whose target no
    # longer exists before the kernel link is installed.
    find "$bundleNodeModules" -depth -type l ! -exec test -e {} \; -delete 2>/dev/null || true

    find "$bundleNodeModules" -depth -type d \( -name "@" -o -name "@deepseek-ai" \) -empty -delete 2>/dev/null || true

    while IFS= read -r reserved; do
      [ -n "$reserved" ] || continue
      is_kernel_peer_kept "$reserved" && continue
      if [ -e "$bundleNodeModules/$reserved" ]; then
        printf 'buildDshBundle: kernel runtime package was not pruned: %s\n' "$reserved" >&2
        exit 1
      fi
    done < "$reservedList"

    link_kernel_into_package() {
      local moduleRoot="$1/node_modules"

      if [ ! -e "$moduleRoot" ] && [ ! -L "$moduleRoot" ]; then
        ln -s "$kernelNodeModules" "$moduleRoot"
        return
      fi

      # A bundle-local node_modules keeps its own dependencies (for example
      # dsh-cc-tui's auto-bind). Kernel-owned peers are linked into it so both
      # resolve without duplicating the kernel runtime.
      mkdir -p "$moduleRoot"
      while IFS= read -r reserved; do
        [ -n "$reserved" ] || continue
        if [ ! -e "$moduleRoot/$reserved" ] && [ ! -L "$moduleRoot/$reserved" ]; then
          case "$reserved" in
            @*)
              mkdir -p "$moduleRoot/''${reserved%/*}"
              ln -s "$kernelNodeModules/$reserved" "$moduleRoot/$reserved"
              ;;
            *)
              ln -s "$kernelNodeModules/$reserved" "$moduleRoot/$reserved"
              ;;
          esac
        fi
      done < "$reservedList"
    }

    for entry in "$out"/lib/node_modules/*; do
      [ -d "$entry" ] || continue
      case "$(basename "$entry")" in
        .*)
          continue
          ;;
        @*)
          for pkg in "$entry"/*; do
            [ -d "$pkg" ] || continue
            link_kernel_into_package "$pkg"
          done
          ;;
        *)
          link_kernel_into_package "$entry"
          ;;
      esac
    done
  '';

  # Build a bundle from its own npm source. Use this for external bundles that
  # are not produced by the upstream workspace build.
  buildDshBundle = lib.extendMkDerivation {
    constructDrv = buildNpmPackage;
    excludeDrvArgNames = [
      "linkKernelNodeModules"
      "linkKernelNodeModulesKeep"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        runtimeDeps ? [ ],
        linkKernelNodeModules ? null,
        linkKernelNodeModulesKeep ? [ ],
        nativeBuildInputs ? [ ],
        disallowedReferences ? [ ],
        meta ? { },
        passthru ? { },
        postInstall ? "",
        ...
      }:
      let
        bundleProtocol = validateProtocol { inherit runtimeDeps; };
      in
      {
        nodejs = nodejs-slim;
        disallowedReferences = lib.unique (disallowedReferences ++ [ nodejs ]);
        nativeBuildInputs = [
          nodejs-slim
          nodejs-slim.npm
        ]
        ++ nativeBuildInputs;
        passthru = passthru // bundleProtocol;
        postInstall =
          postInstall
          + lib.optionalString (linkKernelNodeModules != null) (
            linkKernelNodeModulesScript linkKernelNodeModules linkKernelNodeModulesKeep
          )
          + validateInstalledBundle;
        meta = meta // {
          description =
            meta.description or (throw "buildDshBundle: ${finalAttrs.pname} requires meta.description");
        };
      };
  };

  # Build a bundle from an external pnpm workspace by deploying one package
  # directly into the standard bundle output layout.
  fromPnpmWorkspace = lib.extendMkDerivation {
    constructDrv = buildNpmPackage;
    excludeDrvArgNames = [
      "deployPackage"
      "disableChildBundlePatches"
      "linkKernelNodeModules"
      "linkKernelNodeModulesKeep"
      "pnpm"
      "postDeploy"
      "preDeploy"
      "runtimeDeps"
      "stripPrepareScripts"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        deployPackage,
        runtimeDeps ? [ ],
        preDeploy ? "",
        postDeploy ? "",
        stripPrepareScripts ? false,
        disableChildBundlePatches ? false,
        linkKernelNodeModules ? null,
        linkKernelNodeModulesKeep ? [ ],
        pnpm ? pnpm_11,
        nativeBuildInputs ? [ ],
        disallowedReferences ? [ ],
        meta ? { },
        passthru ? { },
        postInstall ? "",
        ...
      }:
      let
        bundleProtocol = validateProtocol { inherit runtimeDeps; };
        defaultInstallPhase = ''
          runHook preInstall

          ${lib.optionalString stripPrepareScripts ''
            if [ -d packages ]; then
              find packages -name package.json -print0 \
                | xargs -0 -n1 sh -c '
                    jq "del(.scripts.prepare)" "$0" > "$0.tmp"
                    mv "$0.tmp" "$0"
                  '
            else
              jq "del(.scripts.prepare)" package.json > package.json.tmp
              mv package.json.tmp package.json
            fi
          ''}
          ${preDeploy}

          pnpm config set --location=project inject-workspace-packages true
          pnpm --filter ${lib.escapeShellArg deployPackage} deploy \
            --prod \
            --config.node-linker=hoisted \
            --config.link-workspace-packages=true \
            "$out/lib"

          deployPackagePath="$out/lib/node_modules/${lib.escapeShellArg deployPackage}"
          ${lib.optionalString disableChildBundlePatches suppressChildBundlePatches}
          ${postDeploy}

          runHook postInstall
        '';
      in
      {
        nodejs = nodejs-slim;
        disallowedReferences = lib.unique (
          disallowedReferences
          ++ [
            nodejs
            pnpm
          ]
        );
        nativeBuildInputs = [
          nodejs-slim
          nodejs-slim.npm
          pnpm
        ]
        ++ lib.optionals stripPrepareScripts [ jq ]
        ++ nativeBuildInputs;
        passthru = passthru // bundleProtocol;
        installPhase = defaultInstallPhase;
        postInstall =
          postInstall
          + lib.optionalString (linkKernelNodeModules != null) (
            linkKernelNodeModulesScript linkKernelNodeModules linkKernelNodeModulesKeep
          )
          + validateInstalledBundle;
        meta = meta // {
          description =
            meta.description or (throw "buildDshBundle: ${finalAttrs.pname} requires meta.description");
        };
      };
  };

  # Package artifacts emitted by dsh-workspace. Use this for upstream bundles
  # so the monorepo is built once and reused by the runtime packages.
  fromWorkspace = lib.extendMkDerivation {
    constructDrv = stdenvNoCC.mkDerivation;
    excludeDrvArgNames = [
      "artifacts"
      "packageName"
      "dsh-kernel"
      "dsh-workspace"
      "linkKernelNodeModules"
      "linkKernelNodeModulesKeep"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        packageName,
        artifacts ? [ ],
        dsh-kernel,
        dsh-workspace,
        disallowedReferences ? [ ],
        linkKernelNodeModules ? null,
        linkKernelNodeModulesKeep ? [ ],
        nativeBuildInputs ? [ ],
        runtimeDeps ? [ ],
        version ? dsh-workspace.version,
        installPhase ? null,
        meta ? { },
        passthru ? { },
        postInstall ? "",
        ...
      }:
      let
        bundleProtocol = validateProtocol { inherit runtimeDeps; };
        bundleSource = "${dsh-workspace}/lib/dsh-workspace/runtime-bundles/${packageName}";
        defaultInstallPhase = ''
          runHook preInstall

          source="${bundleSource}"
          destination="$out/lib/node_modules/${packageName}"
          [ -d "$source" ] || {
            printf 'buildDshBundle: workspace bundle is missing: %s\n' "$source" >&2
            exit 1
          }
          mkdir -p "$destination"
          cp -r "$source"/. "$destination"/
          chmod -R u+w "$destination"

          ${lib.concatMapStringsSep "\n" (artifact: ''
            source="${dsh-workspace}/lib/dsh-workspace/${artifact.source}"
            destination="$out/${artifact.target}"
            [ -d "$source" ] || {
              printf 'buildDshBundle: workspace artifact is missing: %s\n' "$source" >&2
              exit 1
            }
            mkdir -p "$destination"
            cp -r "$source"/. "$destination"/
            chmod -R u+w "$destination"
          '') artifacts}

          runHook postInstall
        '';
      in
      {
        inherit version;
        src = dsh-workspace;
        # The workspace is only the build source. Runtime dependencies come
        # from the independently consumable kernel package.
        disallowedReferences = lib.unique (disallowedReferences ++ [ dsh-workspace ]);
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        installPhase = if installPhase == null then defaultInstallPhase else installPhase;
        nativeBuildInputs = [ nodejs-slim ] ++ nativeBuildInputs;
        postInstall =
          postInstall
          + lib.optionalString (linkKernelNodeModules != null) (
            linkKernelNodeModulesScript linkKernelNodeModules linkKernelNodeModulesKeep
          )
          + validateInstalledBundle;
        passthru = passthru // bundleProtocol;
        meta = meta // {
          description =
            meta.description or (throw "buildDshBundle: ${finalAttrs.pname} requires meta.description");
        };
      };
  };
in
buildDshBundle
// {
  inherit dshBundleResolver fromPnpmWorkspace fromWorkspace;
}
