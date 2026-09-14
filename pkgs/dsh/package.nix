{
  lib,
  coreutils,
  curl,
  diffutils,
  gnugrep,
  jq,
  stdenvNoCC,
  linkFarm,
  makeWrapper,
  nodejs,
  nodejs-slim,
  runCommand,
  symlinkJoin,
  util-linux,
  writeShellApplication,
  writeText,
  writers,
  yq-go,

  buildDshBundle,
  dsh,
  dshBundleCheckHook,
  dsh-kernel,
  writableTmpDirAsHomeHook,

  bundles,

  # Bundles included in every composed application.
  defaultBundles ? with bundles; [
    headless
    web-app
  ],

  # Profiles materialized under $DSH_HOME/profiles/nix-<name>.
  profiles ? { },
  # Agent Preset definitions referenced by profiles.
  agentPresets ? { },
  # Optional profile used when the caller does not pass --profile.
  defaultProfile ? null,
  # Optional home-level Cordis patch managed under $DSH_HOME.
  homePatch ? null,
  # Optional external profile artifact seeder used by split integrations.
  profileSeeder ? null,
  profileDefaultProfile ? null,
  pname ? "dsh",
  meta ? { },
}:

let
  composition = import ./composition.nix {
    inherit lib;
    validateDshBundle = buildDshBundle.validateDshBundle;
  };
  mkDsh = import ../../lib/mk-dsh.nix;
  dshBundleResolver = buildDshBundle.dshBundleResolver;
  profileSupport = import ./profiles.nix {
    inherit
      baseBundle
      coreutils
      diffutils
      gnugrep
      dshBundleResolver
      dsh-kernel
      headlessBundle
      lib
      linkFarm
      runCommand
      util-linux
      writeShellApplication
      writeText
      writers
      tuiBundle
      webBundle
      yq-go
      ;
  };

  baseBundle = bundles.base;
  headlessBundle = bundles.headless;
  tuiBundle = bundles.tui;
  webBundle = bundles.web-app;
  profileArtifacts = profileSupport.mkProfileArtifacts {
    inherit agentPresets defaultBundles profiles;
    inherit defaultProfile homePatch;
  };
  profilesForComposition = profileArtifacts.profilesForComposition;
  managedProfileNames = map profileSupport.profileName (lib.attrNames profiles);
  validatedDefaultProfile = profileArtifacts.validatedDefaultProfile;
  validatedHomePatch = profileArtifacts.validatedHomePatch;

  resolveBundles =
    bundlesOrSelector:
    if lib.isFunction bundlesOrSelector then
      bundlesOrSelector bundles
    else if lib.isList bundlesOrSelector then
      bundlesOrSelector
    else
      [ bundlesOrSelector ];

  profileRequiresTty =
    profile:
    (profile.requiresTty or false)
    || profileSupport.profileNeedsTui profile
    || lib.any (bundle: bundle.passthru.requiresTty or false) (profile.bundles or [ ]);

  profileRequiresWeb = profileSupport.profileNeedsWeb;
  compositionConfig = {
    package = dsh;
    inherit
      agentPresets
      defaultBundles
      profiles
      ;
    defaultProfile = validatedDefaultProfile;
    patch = validatedHomePatch;
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (dsh-kernel) version;

  src = null;
  disallowedReferences = [ nodejs ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    jq
    makeWrapper
  ];

  installPhase =
    let
      dshWrapper = ''
        makeWrapper ${lib.getExe nodejs-slim} "$out/bin/dsh-real" \
      ''
      + lib.optionalString (finalAttrs.passthru.runtimeDeps != [ ]) ''
        --prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} \
      ''
      + ''
        --add-flags "--expose-internals" \
        --add-flags "$appDir/lib/bin.js"
      '';
      dshSeedWrapper =
        if profileSeeder == null && profiles == { } && validatedHomePatch == null then
          null
        else
          writeShellApplication {
            name = "dsh-seed-profile";
            runtimeInputs = [ finalAttrs.passthru.seedProfiles ];
            text = ''
              requested_profile=
              has_profile=0
              wants_profile_value=0
              for arg in "$@"; do
                if [ "$wants_profile_value" -eq 1 ]; then
                  requested_profile=$arg
                  wants_profile_value=0
                  continue
                fi

                case "$arg" in
                  --) break ;;
                  --profile)
                    wants_profile_value=1
                    has_profile=1
                    ;;
                  --profile=*)
                    requested_profile=''${arg#--profile=}
                    has_profile=1
                    ;;
                esac
              done

              if [ "$has_profile" -eq 1 ]; then
                dsh-sync-profiles "$requested_profile"
            ''
            + lib.optionalString (launcherDefaultProfile != null) ''
              else
                dsh-sync-profiles ${lib.escapeShellArg launcherDefaultProfile}
                set -- --profile ${lib.escapeShellArg launcherDefaultProfile} "$@"
            ''
            + lib.optionalString (launcherDefaultProfile == null) ''
              else
                dsh-sync-profiles
            ''
            + ''
              fi

              real_dsh=''${DSH_REAL:?DSH_REAL is not set}
              exec "$real_dsh" "$@"
            '';
          };
      launcherDefaultProfile =
        if profileSeeder == null then validatedDefaultProfile else profileDefaultProfile;
      profileLauncher =
        if dshSeedWrapper == null then
          ''
            mv "$out/bin/dsh-real" "$out/bin/dsh"
          ''
        else
          ''
            makeWrapper ${dshSeedWrapper}/bin/dsh-seed-profile "$out/bin/dsh" \
              --set DSH_REAL "$out/bin/dsh-real"
          '';
    in
    ''
      kernelApp="${dsh-kernel}/lib/deepseek-harness"
      appDir="$out/lib/deepseek-harness"

      mkdir -p "$appDir"
      # Copy lib so the profile heal anchors at this manifest, not the kernel's.
      cp -r "$kernelApp/lib" "$appDir/lib"
      ln -s "$kernelApp/config" "$appDir/config"
      cp "$kernelApp/package.json" "$appDir/package.json"
      ln -s "${finalAttrs.passthru.nodeModules}" "$appDir/node_modules"

      mkdir -p "$out/nix-support"
      ${lib.getExe dshBundleResolver} merge \
        "$out/nix-support/dsh-bundles.json" \
        ${lib.concatMapStringsSep " " (
          bundle: lib.escapeShellArg "${bundle}/nix-support/dsh-bundles.json"
        ) finalAttrs.passthru.composedBundles}
      # Profiles resolve through $DSH_HOME, so advertise every package mounted
      # by this installation to the profile module fallback.
      runtimeDependencies="$TMPDIR/dsh-runtime-dependencies.json"
      printf '{}\n' > "$runtimeDependencies"
      for packageJson in "$appDir/node_modules"/*/package.json "$appDir/node_modules"/@*/*/package.json; do
        [ -f "$packageJson" ] || continue
        packageName=$(jq -r '.name | select(type == "string" and length > 0)' "$packageJson")
        packageVersion=$(jq -r '.version | select(type == "string" and length > 0)' "$packageJson")
        [ -n "$packageName" ] && [ -n "$packageVersion" ] || continue
        jq --arg name "$packageName" --arg version "$packageVersion" \
          '.[$name] = $version' "$runtimeDependencies" > "$runtimeDependencies.tmp"
        mv "$runtimeDependencies.tmp" "$runtimeDependencies"
      done
      jq --slurpfile bundles "$out/nix-support/dsh-bundles.json" \
        --slurpfile runtimeDependencies "$runtimeDependencies" \
        '.dependencies *= ($bundles[0].bundles | map({key: .name, value: .version}) | from_entries) | .dependencies *= $runtimeDependencies[0]' \
        "$appDir/package.json" > "$appDir/package.json.tmp"
      mv "$appDir/package.json.tmp" "$appDir/package.json"

      mkdir -p "$out/bin"
      ${dshWrapper}
      ${profileLauncher}

      runHook postInstall
    '';

  __darwinAllowLocalNetworking = true;
  doInstallCheck = true;
  nativeInstallCheckInputs = [
    dshBundleCheckHook
    curl
    util-linux
    writableTmpDirAsHomeHook
  ];
  dshBundleCheckProfiles = lib.concatStringsSep " " managedProfileNames;
  dshBundleCheckWebProfiles = lib.concatStringsSep " " (
    lib.flatten (
      lib.mapAttrsToList (
        name: profile: lib.optional (profileRequiresWeb profile) (profileSupport.profileName name)
      ) profiles
    )
  );
  # Profiles that need a real terminal enter an interactive loop instead of
  # exiting after --help; dshBundleCheckHook treats a booted, still-running
  # smoke window as success for these.
  dshBundleCheckTtyProfiles = lib.concatStringsSep " " (
    lib.flatten (
      lib.mapAttrsToList (
        name: profile: lib.optional (profileRequiresTty profile) (profileSupport.profileName name)
      ) profiles
    )
  );
  installCheckPhase = ''
    runHook preInstallCheck
    DSH_HOME="$TMPDIR/dsh" "$out/bin/dsh" --version
    runHook postInstallCheck
  '';

  passthru = {
    inherit bundles defaultBundles;

    config = builtins.removeAttrs compositionConfig [ "package" ];

    defaultProfileName = validatedDefaultProfile;
    profileNames = managedProfileNames;

    composedBundles = composition.composeBundles {
      base = baseBundle;
      defaults = defaultBundles;
      profiles = profilesForComposition;
    };

    mkProfileArtifacts =
      args:
      profileSupport.mkProfileArtifacts (
        args
        // {
          defaultBundles = lib.attrByPath [ "defaultBundles" ] defaultBundles args;
        }
      );

    profileTemplates = profileArtifacts.profileTemplates;

    agentPresetTemplates = profileArtifacts.agentPresetTemplates;

    seedProfiles = if profileSeeder == null then profileArtifacts.seedProfiles else profileSeeder;

    nodeModules = symlinkJoin {
      name = "dsh-node-modules";
      paths = [
        "${dsh-kernel}/lib/deepseek-harness/node_modules"
      ]
      # symlinkJoin keeps the first file on collisions. Reverse the bundle
      # paths so a later Cordis layer also wins for overlapping runtime files.
      ++ (map (bundle: "${bundle}/lib/node_modules") (
        lib.reverseList finalAttrs.passthru.composedBundles
      ));
    };

    runtimeDeps = lib.unique (
      dsh-kernel.passthru.runtimeDeps
      ++ composition.runtimeDeps (lib.reverseList finalAttrs.passthru.composedBundles)
    );

    # pkgs.dsh.dsh.withProfiles { tui.bundles = b: with b; [ tui ]; }
    # materializes the profile as nix-tui.
    withProfiles =
      configuredProfiles:
      mkDsh (
        compositionConfig
        // {
          defaultProfile = null;
          profiles = lib.mapAttrs (
            _: profile:
            profile
            // {
              bundles = resolveBundles (profile.bundles or [ ]);
            }
          ) configuredProfiles;
        }
      );

    # pkgs.dsh.dsh.withAgentPresets { web-subagents = { source = "standard"; }; }
    # merges definitions by ID; a later definition replaces an earlier one.
    withAgentPresets =
      configuredAgentPresets:
      assert lib.isAttrs configuredAgentPresets;
      mkDsh (
        compositionConfig
        // {
          agentPresets = agentPresets // configuredAgentPresets;
        }
      );

    # pkgs.dsh.dsh.withBundles (b: with b; [ tui web-app ])
    # pkgs.dsh.dsh.withBundles [ pkgs.dsh.bundles.tui pkgs.dsh.bundles.web-app ]
    # adds selected bundles to the current composition and to every managed
    # profile so Nix-managed profiles stay in sync with the running package.
    withBundles =
      bundlesOrSelector:
      let
        selectedBundles = resolveBundles bundlesOrSelector;
        profilesWithBundles = lib.mapAttrs (
          _: profile:
          profile
          // {
            bundles = lib.unique ((resolveBundles (profile.bundles or [ ])) ++ selectedBundles);
          }
        ) profiles;
      in
      assert lib.isList selectedBundles;
      mkDsh (
        compositionConfig
        // {
          defaultBundles = lib.unique (defaultBundles ++ selectedBundles);
          profiles = profilesWithBundles;
        }
      );
  };

  meta = {
    description = "DeepSeek Harness agent CLI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  }
  // meta;
})
