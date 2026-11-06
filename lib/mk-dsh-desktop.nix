{
  lib,
  makeWrapper,
  symlinkJoin,
  writers,
}:
cfg:
let
  desktop = cfg.desktop.package;
  selected = lib.filter (profile: profile.materializedName == cfg.desktop.profile) (
    lib.attrValues cfg.profiles
  );
  artifacts = cfg.package.passthru.mkProfileArtifacts {
    inherit (cfg) profiles agentPresets;
    desktopProfile = cfg.desktop.profile;
    defaultProfile = cfg.desktop.profile;
    homePatch = cfg.patch;
  };
  profileConfig = writers.writeJSON "dsh-desktop-profile.json" {
    home = cfg.home;
    profile = artifacts.validatedDefaultProfile;
    seeder = lib.getExe artifacts.seedProfiles;
    mode = (builtins.head selected).mode;
  };
in
# The desktop package stays independent of the configuration; only its
# launcher selects the declared profile.
if cfg.desktop.profile == null then
  desktop
else
  lib.throwIf (selected == [ ])
    "dsh desktop: desktop.profile must reference a declared programs.dsh.profiles entry"
    (symlinkJoin {
      inherit (desktop) pname version;
      paths = [ desktop ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        rm "$out/bin/dsh-desktop"
        makeWrapper ${lib.getExe desktop} "$out/bin/dsh-desktop" \
          --set DSH_NIX_DESKTOP_PROFILE_CONFIG ${profileConfig}
      '';
      inherit (desktop) meta passthru;
    })
