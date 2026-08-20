{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.dsh;
in

{
  imports = [ ./shared-profile-options.nix ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      ((cfg.package.withProfiles cfg.profiles).override {
        defaultProfile = cfg.defaultProfile;
      })
    ];

    environment.variables = lib.mkIf (cfg.home != null) {
      DSH_HOME = cfg.home;
    };
  };
}
