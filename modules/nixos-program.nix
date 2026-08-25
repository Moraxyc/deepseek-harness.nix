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
      (
        (
          (cfg.package.override {
            agentPresets = cfg.agentPresets;
          }).withProfiles
          cfg.profiles
        ).override
        {
          defaultProfile = cfg.defaultProfile;
          homePatch = cfg.patch;
        }
      )
    ];

    environment.variables = lib.mkIf (cfg.home != null) {
      DSH_HOME = cfg.home;
    };
  };
}
