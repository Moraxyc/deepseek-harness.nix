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

  linkKernelNodeModulesScript = kernel: ''
    kernelNodeModules="${kernel}/lib/deepseek-harness/node_modules"
    for entry in "$out"/lib/node_modules/*; do
      [ -d "$entry" ] || continue
      case "$(basename "$entry")" in
        .*)
          continue
          ;;
        @*)
          for pkg in "$entry"/*; do
            [ -d "$pkg" ] || continue
            if [ ! -e "$pkg/node_modules" ] && [ ! -L "$pkg/node_modules" ]; then
              ln -s "$kernelNodeModules" "$pkg/node_modules"
            fi
          done
          ;;
        *)
          if [ ! -e "$entry/node_modules" ] && [ ! -L "$entry/node_modules" ]; then
            ln -s "$kernelNodeModules" "$entry/node_modules"
          fi
          ;;
      esac
    done
  '';

  # Build a bundle from its own npm source. Use this for external bundles that
  # are not produced by the upstream workspace build.
  buildDshBundle = lib.extendMkDerivation {
    constructDrv = buildNpmPackage;
    excludeDrvArgNames = [
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        runtimeDeps ? [ ],
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
        postInstall = postInstall + validateInstalledBundle;
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
          ${lib.optionalString (linkKernelNodeModules != null) (
            linkKernelNodeModulesScript linkKernelNodeModules
          )}

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
        postInstall = postInstall + validateInstalledBundle;
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
      "dsh-kernel"
      "dsh-workspace"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        artifacts,
        dsh-kernel,
        dsh-workspace,
        disallowedReferences ? [ ],
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
        defaultInstallPhase = ''
          runHook preInstall

          ${lib.concatMapStringsSep "\n" (
            artifact:
            let
              linkNodeModules = artifact.linkNodeModules or false;
            in
            ''
              source="${dsh-workspace}/lib/dsh-workspace/${artifact.source}"
              destination="$out/${artifact.target}"
              [ -d "$source" ] || {
                printf 'buildDshBundle: workspace artifact is missing: %s\n' "$source" >&2
                exit 1
              }
              mkdir -p "$destination"
              cp -r "$source"/. "$destination"/
              ${lib.optionalString linkNodeModules ''
                ln -s ${dsh-kernel}/lib/deepseek-harness/node_modules "$destination/node_modules"
              ''}
            ''
          ) artifacts}

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
        postInstall = postInstall + validateInstalledBundle;
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
