{
  lib,
  buildNpmPackage,
  copyTree,
  fetchPnpmDeps,
  jq,
  nodejs,
  nodejs-slim,
  pnpmWorkspaceDeploy,
  pnpmWorkspaceDeployMinVersion,
  stdenvNoCC,
  writeShellApplication,
  writers,
}:

let
  resolveDshBundles = ./resolve-dsh-bundles.mjs;
  shareInstallationPackages = ./share-installation-packages.mjs;
  emptyCordisPatch = writers.writeYAML "empty-cordis.patch.yml" [ ];
  packageLabel = bundle: bundle.pname or bundle.name or "<unknown>";

  protocol = runtimeDeps: {
    dshBundle = true;
    dshBundleHelper = "buildDshBundle";
    inherit runtimeDeps;
  };

  validateDshBundle =
    {
      bundle,
      context ? "dsh composition",
    }:
    let
      passthru = bundle.passthru or { };
      label = packageLabel bundle;
      meta = bundle.meta or { };
      runtimeDeps = passthru.runtimeDeps or [ ];
    in
    lib.throwIfNot (passthru ? dshBundle && passthru.dshBundle == true)
      "${context}: ${label} is not created by mkDshBundle"
      (
        lib.throwIfNot (passthru ? dshBundleHelper && passthru.dshBundleHelper == "buildDshBundle")
          "${context}: ${label} does not use the buildDshBundle protocol"
          (
            lib.throwIfNot (lib.isList runtimeDeps)
              "${context}: ${label} must expose passthru.runtimeDeps as a list"
              (
                lib.throwIfNot (
                  meta ? description && lib.isString meta.description
                ) "${context}: ${label} requires meta.description" bundle
              )
          )
      );

  dshBundleResolver = writeShellApplication {
    name = "dsh-resolve-bundles";
    runtimeInputs = [ nodejs-slim ];
    text = ''
      exec node ${resolveDshBundles} "$@"
    '';
  };

  # dsh skips a bundle whose dsh peer ranges exclude the runtime unless the
  # manifest declares engines.dsh, which then decides alone.
  setDshEnginesScript =
    range:
    lib.optionalString (range != null) ''
      ${lib.getExe dshBundleResolver} set-engines ${lib.escapeShellArg range} "$out/lib/node_modules"
    '';

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

  normalizeDeployPackageLayout = ''
    case "$deployPackagePath" in
      "$out/lib/node_modules"/*)
        ;;
      *)
        printf 'buildDshBundle: invalid deploy package path: %s\n' "$deployPackagePath" >&2
        exit 1
        ;;
    esac

    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    for entry in "$out"/lib/*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      case "$(basename "$entry")" in
        node_modules)
          continue
          ;;
      esac
      mv "$entry" "$deployPackagePath/"
    done

    # pnpm stamps install time and the temporary store path into these
    # bookkeeping files, which makes the output differ between rebuilds.
    rm -f \
      "$out/lib/node_modules/.modules.yaml" \
      "$out/lib/node_modules/.pnpm-workspace-state-v1.json"
  '';

  suppressChildBundlePatches = ''
    suppress_patch() {
      [ "$1" = "$deployPackagePath" ] && return 0

      # Aggregators keep child manifests for dependency resolution, but every
      # declared child patch must be inert, including array entries.
      if [ -f "$1/cordis.patch.yml" ]; then
        cp ${emptyCordisPatch} "$1/cordis.patch.yml"
      fi
      if [ -f "$1/package.json" ]; then
        while IFS= read -r patch; do
          case "$patch" in
            ./*)
              patchPath="$1/''${patch#./}"
              [ -f "$patchPath" ] || continue
              cp ${emptyCordisPatch} "$patchPath"
              ;;
          esac
        done < <(
          jq -r '
            .dsh?.bundle?.patch? // empty
            | if type == "string" then .
              elif type == "array" then .[]
              else empty
              end
          ' "$1/package.json"
        )
      fi
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

  # Bundles carry their own dependencies; peers resolve from the installation.
  # Copies of installation packages become links into it, so a plugin and the
  # installation share one module instance.
  shareInstallationScript = installation: keep: ''
    installationNodeModules="${installation}/node_modules"
    [ -d "$installationNodeModules" ] || {
      printf 'buildDshBundle: installation node_modules is missing: %s\n' "$installationNodeModules" >&2
      exit 1
    }
    ${lib.getExe nodejs-slim} ${shareInstallationPackages} \
      "$out/lib/node_modules" "$installationNodeModules" ${lib.escapeShellArgs keep}
    # Shared packages leave dangling .bin links that noBrokenSymlinks rejects.
    find "$out/lib/node_modules" -xtype l -delete
  '';

  # Every builder exposes the same protocol surface: validated passthru,
  # installation package sharing, engines rewrite, and the bundle manifest.
  mkBundleProtocol =
    finalAttrs:
    {
      runtimeDeps ? [ ],
      meta ? { },
      passthru ? { },
      postInstall ? "",
      dshEngines ? null,
      installation ? null,
      installationKeep ? [ ],
    }:
    let
      validation = validateDshBundle {
        bundle = {
          inherit meta;
          passthru = protocol runtimeDeps;
          pname = finalAttrs.pname;
        };
        context = "buildDshBundle";
      };
    in
    {
      inherit (validation) meta;
      passthru = passthru // validation.passthru // { inherit dshEngines; };
      postInstall =
        postInstall
        + lib.optionalString (installation != null) (shareInstallationScript installation installationKeep)
        + setDshEnginesScript dshEngines
        + validateInstalledBundle;
    };

  buildDshBundle = lib.extendMkDerivation {
    constructDrv = buildNpmPackage;
    excludeDrvArgNames = [
      "disableChildBundlePatches"
      "dshEngines"
      "installation"
      "installationKeep"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        runtimeDeps ? [ ],
        disableChildBundlePatches ? false,
        dshEngines ? null,
        installation ? null,
        installationKeep ? [ ],
        nativeBuildInputs ? [ ],
        disallowedReferences ? [ ],
        env ? { },
        meta ? { },
        passthru ? { },
        postInstall ? "",
        ...
      }:
      {
        nodejs = nodejs-slim;
        env = env // {
          PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
        };
        disallowedReferences = lib.unique (disallowedReferences ++ [ nodejs ]);
        nativeBuildInputs = [
          nodejs-slim
          nodejs-slim.npm
        ]
        ++ lib.optional disableChildBundlePatches jq
        ++ nativeBuildInputs;
      }
      // mkBundleProtocol finalAttrs {
        inherit
          dshEngines
          installation
          installationKeep
          meta
          passthru
          runtimeDeps
          ;
        postInstall = postInstall + lib.optionalString disableChildBundlePatches suppressChildBundlePatches;
      };
  };

  fromPnpmWorkspace = lib.extendMkDerivation {
    constructDrv = buildNpmPackage;
    excludeDrvArgNames = [
      "deployPackage"
      "disableChildBundlePatches"
      "dshEngines"
      "installation"
      "installationKeep"
      "pnpm"
      "pnpmDepsHash"
      "postDeploy"
      "postNormalizeDeploy"
      "preDeploy"
      "runtimeDeps"
      "stripPrepareScripts"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        deployPackage,
        pnpmDeps ? null,
        pnpmDepsHash ? null,
        runtimeDeps ? [ ],
        preDeploy ? "",
        postDeploy ? "",
        postNormalizeDeploy ? "",
        stripPrepareScripts ? false,
        disableChildBundlePatches ? false,
        dshEngines ? null,
        installation ? null,
        installationKeep ? [ ],
        pnpm ? pnpmWorkspaceDeploy,
        nativeBuildInputs ? [ ],
        disallowedReferences ? [ ],
        env ? { },
        meta ? { },
        passthru ? { },
        postInstall ? "",
        ...
      }:
      let
        resolvedPnpmDeps =
          if pnpmDeps != null then
            pnpmDeps
          else if pnpmDepsHash != null then
            fetchPnpmDeps {
              inherit (finalAttrs) pname version src;
              fetcherVersion = 4;
              hash = pnpmDepsHash;
            }
          else
            null;
        defaultInstallPhase = ''
          runHook preInstall
        ''
        + lib.optionalString stripPrepareScripts ''
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
        ''
        + preDeploy
        + ''
          pnpm config set --location=project inject-workspace-packages true
          # Deploy must not rerun native dependency install scripts.
          pnpm --filter ${lib.escapeShellArg deployPackage} deploy \
            --prod \
            --ignore-scripts \
            --config.node-linker=hoisted \
            --config.link-workspace-packages=true \
            "$out/lib"

          deployPackagePath="$out/lib/node_modules/${deployPackage}"
        ''
        + lib.optionalString disableChildBundlePatches suppressChildBundlePatches
        + postDeploy
        + normalizeDeployPackageLayout
        + postNormalizeDeploy
        + ''

          runHook postInstall
        '';
      in
      assert lib.assertMsg (pnpmDeps == null || pnpmDepsHash == null)
        "buildDshBundle.fromPnpmWorkspace: ${finalAttrs.pname} sets both pnpmDeps and pnpmDepsHash; pass only one.";
      assert lib.assertMsg (lib.versionAtLeast pnpm.version pnpmWorkspaceDeployMinVersion)
        "buildDshBundle.fromPnpmWorkspace: ${finalAttrs.pname} requires pnpm >= ${pnpmWorkspaceDeployMinVersion} for workspace injection, got ${pnpm.version}. Leave `pnpm` unset to use `pnpmWorkspaceDeploy`, or pass `pnpm = pnpmWorkspaceDeploy` explicitly.";
      {
        nodejs = nodejs-slim;
        env = env // {
          PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
        };
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
        ++ lib.optionals (stripPrepareScripts || disableChildBundlePatches) [ jq ]
        ++ nativeBuildInputs;
        installPhase = defaultInstallPhase;
      }
      // mkBundleProtocol finalAttrs {
        inherit
          dshEngines
          installation
          installationKeep
          meta
          passthru
          runtimeDeps
          ;
        inherit postInstall;
      }
      // lib.optionalAttrs (resolvedPnpmDeps != null) {
        pnpmDeps = resolvedPnpmDeps;
      };
  };

  fromWorkspace = lib.extendMkDerivation {
    constructDrv = stdenvNoCC.mkDerivation;
    excludeDrvArgNames = [
      "artifacts"
      "packageName"
      "dsh-workspace"
      "dshEngines"
      "installation"
      "installationKeep"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        packageName,
        artifacts ? [ ],
        dsh-workspace,
        disallowedReferences ? [ ],
        dshEngines ? null,
        installation ? null,
        installationKeep ? [ ],
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
        bundleSource = "${dsh-workspace}/lib/dsh-workspace/runtime-bundles/${packageName}";
        defaultInstallPhase = ''
          runHook preInstall

          ${copyTree.keepLinks {
            src = bundleSource;
            dest = "$out/lib/node_modules/${packageName}";
            label = "buildDshBundle: workspace bundle is missing";
          }}

          ${lib.concatMapStringsSep "\n" (
            artifact:
            copyTree.keepLinks {
              src = "${dsh-workspace}/lib/dsh-workspace/${artifact.source}";
              dest = "$out/${artifact.target}";
              label = "buildDshBundle: workspace artifact is missing";
            }
          ) artifacts}

          runHook postInstall
        '';
      in
      {
        inherit version;
        src = dsh-workspace;
        disallowedReferences = lib.unique (disallowedReferences ++ [ dsh-workspace ]);
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        installPhase = if installPhase == null then defaultInstallPhase else installPhase;
        nativeBuildInputs = [ nodejs-slim ] ++ nativeBuildInputs;
      }
      // mkBundleProtocol finalAttrs {
        inherit
          dshEngines
          installation
          installationKeep
          meta
          passthru
          runtimeDeps
          ;
        inherit postInstall;
      };
  };
  # A bundle the dsh installation already carries. Profiles select it by name;
  # its package stays in the installation.
  fromInstallation =
    {
      pname,
      packageName,
      installation,
      meta ? { },
      passthru ? { },
    }:
    let
      validation = validateDshBundle {
        bundle = {
          inherit meta pname;
          passthru = protocol [ ];
        };
        context = "buildDshBundle.fromInstallation";
      };
      packageRoot = "${installation}/node_modules/${packageName}";
    in
    stdenvNoCC.mkDerivation {
      inherit pname;
      inherit (installation) version;
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      nativeBuildInputs = [ jq ];
      installPhase = ''
        runHook preInstall
        jq --arg root ${lib.escapeShellArg packageRoot} '
          if .dsh.bundle.patch == null then error("\(.name) declares no dsh.bundle.patch") else . end
          | {schema: 1, bundles: [{name, version, patch: .dsh.bundle.patch, packageRoot: $root}]}
        ' ${lib.escapeShellArg "${packageRoot}/package.json"} > manifest.json
        install -Dm644 manifest.json "$out/nix-support/dsh-bundles.json"
        runHook postInstall
      '';
      passthru = passthru // validation.passthru // { dshInstallation = true; };
      inherit (validation) meta;
    };
in
buildDshBundle
// {
  inherit
    dshBundleResolver
    fromInstallation
    fromPnpmWorkspace
    fromWorkspace
    validateDshBundle
    ;
}
