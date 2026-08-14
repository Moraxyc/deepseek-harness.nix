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
  symlinkJoin,
  util-linux,
  versionCheckHook,
  writeShellApplication,
  writeText,

  dsh,
  dsh-kernel,

  bundles,

  # Additional bundles included in the composed application.
  extraPlugins ? [ ],
  # Profiles materialized under $DSH_HOME/profiles/nix-<name>.
  profiles ? { },
  # Optional profile used when the caller does not pass --profile.
  defaultProfile ? null,
}:

let
  composition = import ./composition.nix { inherit lib; };
  profileFiles = import ./profiles.nix {
    inherit
      baseBundle
      coreutils
      diffutils
      gnugrep
      lib
      linkFarm
      util-linux
      writeShellApplication
      writeText
      ;
  };

  baseBundle = bundles.base;
  defaultBundles = with bundles; [
    headless
    web-app
  ];
  managedProfileNames = map profileFiles.profileName (lib.attrNames profiles);
in
assert defaultProfile == null || lib.elem defaultProfile managedProfileNames;

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

    jq --argjson deps '${builtins.toJSON (lib.listToAttrs finalAttrs.passthru.bundleDeps)}' \
      '.dependencies *= $deps' \
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

    ${lib.optionalString (profiles != { }) ''
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

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    composedBundles = composition.composeBundles {
      base = baseBundle;
      defaults = defaultBundles;
      inherit extraPlugins profiles;
    };

    profileTemplates = profileFiles.makeProfileTemplates {
      inherit profiles;
    };

    seedProfiles = profileFiles.makeProfileSeeder {
      inherit profiles;
      profileTemplates = finalAttrs.passthru.profileTemplates;
    };

    nodeModules = symlinkJoin {
      name = "dsh-node-modules";
      paths = [
        "${dsh-kernel}/lib/deepseek-harness/node_modules"
      ]
      ++ (map (bundle: "${bundle}/lib/node_modules") finalAttrs.passthru.composedBundles);
    };

    bundleDeps = composition.bundleDeps finalAttrs.passthru.composedBundles;

    runtimeDeps = composition.runtimeDeps finalAttrs.passthru.composedBundles;

    dshBundles = composition.dshBundles dsh-kernel finalAttrs.passthru.composedBundles;

    # pkgs.dsh.dsh.withProfiles { tui.bundles = [ pkgs.dsh.bundles.tui ]; }
    # materializes the profile as nix-tui.
    withProfiles =
      configuredProfiles:
      dsh.override {
        inherit extraPlugins;
        defaultProfile = null;
        profiles = configuredProfiles;
      };
  };

  meta = {
    description = "DeepSeek Harness agent CLI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
})
