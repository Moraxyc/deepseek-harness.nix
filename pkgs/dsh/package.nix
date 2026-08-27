{
  lib,
  coreutils,
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
  meta ? { },
}:

let
  composition = import ./composition.nix { inherit lib; };
  dshBundleResolver = buildDshBundle.dshBundleResolver;
  profileFiles = import ./profiles.nix {
    inherit
      baseBundle
      coreutils
      diffutils
      gnugrep
      dshBundleResolver
      dsh-kernel
      agentPresets
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
  tuiBundle = bundles.tui;
  webBundle = bundles.web-app;
  profilesForComposition = lib.mapAttrs (
    _: profile:
    profile
    // {
      bundles = profileFiles.profileBundles profile;
    }
  ) profiles;
  managedProfileNames = map profileFiles.profileName (lib.attrNames profiles);
  homePatchFile =
    if homePatch == null then null else writers.writeYAML "dsh-home-cordis.patch.yml" homePatch;

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
    || profileFiles.profileNeedsTui profile
    || lib.any (bundle: bundle.passthru.requiresTty or false) (profile.bundles or [ ]);

  profileRequiresWeb = profileFiles.profileNeedsWeb;
in
assert defaultProfile == null || lib.elem defaultProfile managedProfileNames;
assert homePatch == null || lib.isList homePatch;

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh";
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

  installPhase = ''
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
    jq --slurpfile bundles "$out/nix-support/dsh-bundles.json" \
      '.dependencies *= ($bundles[0].bundles | map({key: .name, value: .version}) | from_entries)' \
      "$appDir/package.json" > "$appDir/package.json.tmp"
    mv "$appDir/package.json.tmp" "$appDir/package.json"

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs-slim} $out/bin/dsh \
      ${
        lib.optionalString (
          finalAttrs.passthru.runtimeDeps != [ ]
        ) "--prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} "
      }\
      --add-flags "--expose-internals" \
      --add-flags "$appDir/lib/bin.js"

    ${lib.optionalString (profiles != { } || homePatch != null) ''
      wrapProgram $out/bin/dsh \
        --run ${lib.escapeShellArg ''
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
            ${lib.escapeShellArg (lib.getExe finalAttrs.passthru.seedProfiles)} "$requested_profile"
          ${lib.optionalString (defaultProfile != null) ''
            else
              ${lib.escapeShellArg (lib.getExe finalAttrs.passthru.seedProfiles)} ${lib.escapeShellArg defaultProfile}
              set -- --profile ${lib.escapeShellArg defaultProfile} "$@"
          ''}
          ${lib.optionalString (defaultProfile == null) ''
            else
              ${lib.escapeShellArg (lib.getExe finalAttrs.passthru.seedProfiles)}
          ''}
          fi
        ''}
    ''}

    runHook postInstall
  '';

  __darwinAllowLocalNetworking = true;
  doInstallCheck = true;
  nativeInstallCheckInputs = [
    dshBundleCheckHook
    util-linux
  ];
  dshBundleCheckProfiles = lib.concatStringsSep " " managedProfileNames;
  dshBundleCheckWebProfiles = lib.concatStringsSep " " (
    lib.flatten (
      lib.mapAttrsToList (
        name: profile: lib.optional (profileRequiresWeb profile) (profileFiles.profileName name)
      ) profiles
    )
  );
  # Profiles that need a real terminal enter an interactive loop instead of
  # exiting after --help; dshBundleCheckHook treats a booted, still-running
  # smoke window as success for these.
  dshBundleCheckTtyProfiles = lib.concatStringsSep " " (
    lib.flatten (
      lib.mapAttrsToList (
        name: profile: lib.optional (profileRequiresTty profile) (profileFiles.profileName name)
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

    defaultProfileName = defaultProfile;

    composedBundles = composition.composeBundles {
      base = baseBundle;
      defaults = defaultBundles;
      profiles = profilesForComposition;
    };

    profileTemplates = profileFiles.makeProfileTemplates {
      inherit profiles;
    };

    agentPresetTemplates = profileFiles.makeAgentPresetTemplates { };

    seedProfiles = profileFiles.makeProfileSeeder {
      inherit homePatchFile profiles;
      agentPresetTemplates = finalAttrs.passthru.agentPresetTemplates;
      profileTemplates = finalAttrs.passthru.profileTemplates;
    };

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
      dsh.override {
        inherit agentPresets defaultBundles homePatch;
        defaultProfile = null;
        profiles = lib.mapAttrs (
          _: profile:
          profile
          // {
            bundles = resolveBundles (profile.bundles or [ ]);
          }
        ) configuredProfiles;
      };

    # pkgs.dsh.dsh.withAgentPresets { web-subagents = { source = "standard"; }; }
    # merges definitions by ID; a later definition replaces an earlier one.
    withAgentPresets =
      configuredAgentPresets:
      assert lib.isAttrs configuredAgentPresets;
      dsh.override {
        inherit
          defaultBundles
          defaultProfile
          homePatch
          profiles
          ;
        agentPresets = agentPresets // configuredAgentPresets;
      };

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
      dsh.override {
        inherit agentPresets defaultProfile homePatch;
        defaultBundles = lib.unique (defaultBundles ++ selectedBundles);
        profiles = profilesWithBundles;
      };
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
