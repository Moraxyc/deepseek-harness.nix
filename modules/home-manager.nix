{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dsh;
  inherit (pkgs.dsh) mkDshRuntime;
  desktopPackage = pkgs.dsh.mkDshDesktop cfg;
  profileArtifacts = cfg.package.passthru.mkProfileArtifacts {
    inherit (cfg) agentPresets defaultProfile;
    desktopProfile = if cfg.desktop.enable then cfg.desktop.profile else null;
    profiles = cfg.profiles;
    homePatch = cfg.patch;
  };
  runtimePackage = mkDshRuntime {
    package = cfg.package;
    profileSeeder =
      if cfg.profiles == { } && cfg.patch == null then null else profileArtifacts.seedProfiles;
    defaultProfile = profileArtifacts.validatedDefaultProfile;
    inherit (profileArtifacts) bundleCheckProfiles;
  };
in
{
  imports = [
    ./shared-profile-options.nix
    ./home-manager-service.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf cfg.desktop.enable {
      home.packages = [ desktopPackage ];
    })
    (lib.mkIf cfg.enable {
      home.packages = [ runtimePackage ];

      home.sessionVariables = lib.mkIf (cfg.home != null) {
        DSH_HOME = cfg.home;
      };

      home.activation.dsh = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.optionalString (cfg.home != null) "DSH_HOME=${lib.escapeShellArg cfg.home} "
        + lib.getExe profileArtifacts.seedProfiles
      );
    })
  ];
}
