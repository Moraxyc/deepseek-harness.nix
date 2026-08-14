{
  lib,
  formats,
  coreutils,
  jq,
  stdenvNoCC,
  linkFarm,
  makeWrapper,
  nodejs-slim,
  symlinkJoin,
  versionCheckHook,
  writeShellApplication,
  writeText,

  dsh,
  dsh-kernel,

  bundles,

  # Additional bundles included in the composed application.
  extraPlugins ? [ ],
  # Profiles copied on first use; see passthru.withProfiles.
  profiles ? { },
}:

let
  composition = import ./composition.nix { inherit lib; };
  profileFiles = import ./profiles.nix {
    inherit
      baseBundle
      formats
      lib
      linkFarm
      writeShellApplication
      writeText
      ;
  };

  baseBundle = bundles.core.base;
  defaultBundles = composition.packagesFromScope bundles.official;
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh";
  inherit (dsh-kernel) version;

  src = null;
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
        --run ${lib.escapeShellArg (lib.getExe finalAttrs.passthru.seedProfiles)}
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
      inherit coreutils;
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

    # pkgs.dsh.withProfiles { tui.bundles = [ pkgs.bundles.optional.tui ]; }
    withProfiles =
      configuredProfiles:
      dsh.override {
        inherit extraPlugins;
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
