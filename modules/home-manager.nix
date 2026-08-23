{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.dsh;
  composed = (cfg.package.withProfiles cfg.profiles).override {
    defaultProfile = cfg.defaultProfile;
    homePatch = cfg.patch;
  };
in
{
  imports = [
    ./shared-profile-options.nix
    ./home-manager-service.nix
  ];

  config = lib.mkIf cfg.enable {
    home.packages = [ composed ];

    home.sessionVariables = lib.mkIf (cfg.home != null) {
      DSH_HOME = cfg.home;
    };

    home.activation.dsh = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.optionalString (cfg.home != null) "DSH_HOME=${lib.escapeShellArg cfg.home} "
      + lib.getExe composed.passthru.seedProfiles
    );
  };
}
