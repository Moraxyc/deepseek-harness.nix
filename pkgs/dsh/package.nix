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
  util-linux,
  writeShellApplication,
  writeText,
  writers,
  yq-go,

  buildDshBundle,
  dsh,
  dshBundleCheckHook,
  dsh-runtime,
  mkDsh,
  writableTmpDirAsHomeHook,

  bundles,

  # Installation that carries @deepseek-ai/dsh and its official bundles.
  runtime ? dsh-runtime,
  # Profiles materialized under $DSH_HOME/profiles/nix-<name>.
  profiles ? { },
  agentPresets ? { },
  # Optional profile used when the caller does not pass --profile.
  defaultProfile ? null,
  desktopProfile ? null,
  # Optional home-level Cordis patch managed under $DSH_HOME.
  homePatch ? null,
  profileSeeder ? null,
  profileDefaultProfile ? null,
  # bundleCheckProfiles from the mkProfileArtifacts call that built profileSeeder.
  profileBundleCheckProfiles ? null,
  pname ? "dsh",
  meta ? { },
}:

let
  dshBundleResolver = buildDshBundle.dshBundleResolver;
  profileSupport = import ./profiles.nix {
    inherit
      coreutils
      diffutils
      gnugrep
      dshBundleResolver
      jq
      lib
      linkFarm
      runCommand
      util-linux
      writeShellApplication
      writeText
      writers
      yq-go
      ;
    inherit (bundles)
      base
      headless
      tui
      web-app
      ;
    installation = runtime;
  };

  profileArtifacts = profileSupport.mkProfileArtifacts {
    inherit agentPresets profiles;
    inherit defaultProfile desktopProfile homePatch;
  };
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

  bundleCheckProfiles =
    if profileSeeder == null then
      profileArtifacts.bundleCheckProfiles
    else
      lib.throwIf (
        profileBundleCheckProfiles == null
      ) "dsh: profileSeeder requires profileBundleCheckProfiles" profileBundleCheckProfiles;
  compositionConfig = {
    package = dsh;
    inherit
      agentPresets
      desktopProfile
      profiles
      runtime
      ;
    defaultProfile = validatedDefaultProfile;
    patch = validatedHomePatch;
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (runtime) version;

  src = null;
  disallowedReferences = [ nodejs ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase =
    let
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

              # Seed positional profile selections before the upstream parser runs.
              if [ "$#" -gt 0 ]; then
                # `dsh plugin` runs pnpm itself, so skip the automatic install.
                [ "$1" != plugin ] || export DSH_NIX_EXTERNAL_INSTALL=0
                case "$1" in
                  --|-*|plugin) ;;
                  *)
                    requested_profile=$1
                    has_profile=1
                    ;;
                esac
              fi

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
    in
    ''
      runHook preInstall

      mkdir -p "$out/bin"
      makeWrapper ${lib.getExe nodejs-slim} "$out/bin/dsh-real" \
        --prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} \
        --add-flags "--expose-internals" \
        --add-flags ${lib.escapeShellArg "${runtime}/node_modules/@deepseek-ai/dsh/lib/bin.js"}
    ''
    + (
      if dshSeedWrapper == null then
        ''
          mv "$out/bin/dsh-real" "$out/bin/dsh"
        ''
      else
        ''
          makeWrapper ${dshSeedWrapper}/bin/dsh-seed-profile "$out/bin/dsh" \
            --set DSH_REAL "$out/bin/dsh-real"
        ''
    )
    + ''
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
  dshBundleCheckProfiles = lib.concatStringsSep " " bundleCheckProfiles.all;
  dshBundleCheckWebProfiles = lib.concatStringsSep " " bundleCheckProfiles.web;
  dshBundleCheckTtyProfiles = lib.concatStringsSep " " bundleCheckProfiles.tty;
  dshBundleCheckExternalBundles = lib.concatStringsSep " " (bundleCheckProfiles.external or [ ]);
  installCheckPhase = ''
    runHook preInstallCheck
    DSH_HOME="$TMPDIR/dsh" "$out/bin/dsh" --version
    runHook postInstallCheck
  '';

  passthru = {
    inherit bundles runtime;
    inherit (runtime.passthru) runtimeDeps;

    config = builtins.removeAttrs compositionConfig [ "package" ];

    defaultProfileName = validatedDefaultProfile;
    profileNames = managedProfileNames;

    # Bundles the declared profiles select, in first-use order.
    profileBundles = lib.unique (
      lib.concatMap (spec: spec.bundles) (lib.attrValues profileArtifacts.profileSpecs)
    );

    inherit (profileSupport) mkProfileArtifacts;

    profileTemplates = profileArtifacts.profileTemplates;

    seedProfiles = if profileSeeder == null then profileArtifacts.seedProfiles else profileSeeder;

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
    # merges definitions by ID. A later definition replaces an earlier one.
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
    # adds the selected bundles to each declared profile.
    withBundles =
      bundlesOrSelector:
      let
        selectedBundles = resolveBundles bundlesOrSelector;
      in
      assert lib.isList selectedBundles;
      lib.throwIf (profiles == { })
        "dsh: withBundles adds bundles to declared profiles; declare one with withProfiles first"
        (
          mkDsh (
            compositionConfig
            // {
              profiles = lib.mapAttrs (
                _: profile:
                profile
                // {
                  bundles = lib.unique ((resolveBundles (profile.bundles or [ ])) ++ selectedBundles);
                }
              ) profiles;
            }
          )
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
