{ lib, cfg }:
let
  selected = lib.filter (profile: profile.materializedName == cfg.desktop.profile) (
    lib.attrValues cfg.profiles
  );
  artifacts = cfg.package.passthru.mkProfileArtifacts {
    inherit (cfg) profiles agentPresets;
    desktopProfile = cfg.desktop.profile;
    defaultProfile = cfg.desktop.profile;
    homePatch = cfg.patch;
  };
  # The seeder lets the host's bundle check boot the declared profiles.
  host = import ./mk-dsh-runtime.nix {
    package = cfg.package;
    bundles = artifacts.runtimeBundles;
    profileSeeder = artifacts.seedProfiles;
    defaultProfile = artifacts.validatedDefaultProfile;
    inherit (artifacts) bundleCheckProfiles;
  };
in
if cfg.desktop.profile == null && !(cfg.desktop.package ? passthru.dshRuntime) then
  cfg.desktop.package
else
  lib.throwIf (cfg.desktop.profile != null && selected == [ ])
    "dsh desktop: desktop.profile must reference a declared programs.dsh.profiles entry"
    (
      cfg.desktop.package.override {
        dshHost = if cfg.desktop.profile == null && cfg.profiles == { } then cfg.package else host;
        desktopProfile =
          if cfg.desktop.profile == null then
            null
          else
            {
              home = cfg.home;
              profile = artifacts.validatedDefaultProfile;
              seeder = lib.getExe artifacts.seedProfiles;
              mode = (builtins.head selected).mode;
            };
      }
    )
