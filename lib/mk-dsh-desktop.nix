{ lib, cfg }:
let
  selected = lib.filterAttrs (name: _: "nix-${name}" == cfg.desktop.profile) cfg.profiles;
  artifacts = cfg.package.passthru.mkProfileArtifacts {
    inherit (cfg) profiles agentPresets;
    defaultProfile = cfg.desktop.profile;
    homePatch = cfg.patch;
  };
  host = import ./mk-dsh-runtime.nix {
    package = cfg.package;
    bundles = artifacts.runtimeBundles;
  };
in
if cfg.desktop.profile == null then
  cfg.desktop.package
else
  lib.throwIf (selected == { })
    "dsh desktop: desktop.profile must reference a declared programs.dsh.profiles entry"
    (
      cfg.desktop.package.override {
        dshHost = host;
        desktopProfile = {
          home = cfg.home;
          profile = artifacts.validatedDefaultProfile;
          seeder = lib.getExe artifacts.seedProfiles;
          mode = (builtins.head (lib.attrValues selected)).mode;
        };
      }
    )
