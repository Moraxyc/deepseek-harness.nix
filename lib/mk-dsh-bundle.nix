{
  lib,
  buildNpmPackage,
  nodejs,
  nodejs-slim,
  stdenvNoCC,
}:

let
  # Shared metadata required by the composition layer for every bundle.
  protocol =
    {
      dshBundles,
      runtimeDeps ? [ ],
    }:
    {
      dshBundle = true;
      dshBundleHelper = "buildDshBundle";
      inherit dshBundles runtimeDeps;
    };

  # Fail early when a package does not implement the public bundle contract.
  validateProtocol =
    {
      dshBundles,
      runtimeDeps,
    }:
    assert lib.isList dshBundles;
    assert lib.all lib.isString dshBundles;
    assert lib.isList runtimeDeps;
    protocol { inherit dshBundles runtimeDeps; };

  # Build a bundle from its own npm source. Use this for external bundles that
  # are not produced by the upstream workspace build.
  buildDshBundle = lib.extendMkDerivation {
    constructDrv = buildNpmPackage;
    excludeDrvArgNames = [
      "dshBundles"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        dshBundles,
        runtimeDeps ? [ ],
        nativeBuildInputs ? [ ],
        disallowedReferences ? [ ],
        meta ? { },
        passthru ? { },
        ...
      }:
      let
        bundleProtocol = validateProtocol { inherit dshBundles runtimeDeps; };
      in
      {
        nodejs = nodejs-slim;
        disallowedReferences = lib.unique (disallowedReferences ++ [ nodejs ]);
        nativeBuildInputs = [ nodejs-slim.npm ] ++ nativeBuildInputs;
        passthru = passthru // bundleProtocol;
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
      "dshBundles"
      "runtimeDeps"
    ];
    extendDrvArgs =
      finalAttrs:
      {
        artifacts,
        dsh-kernel,
        dsh-workspace,
        dshBundles,
        disallowedReferences ? [ ],
        runtimeDeps ? [ ],
        version ? dsh-workspace.version,
        installPhase ? null,
        meta ? { },
        passthru ? { },
        ...
      }:
      let
        bundleProtocol = validateProtocol { inherit dshBundles runtimeDeps; };
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
  inherit fromWorkspace;
}
