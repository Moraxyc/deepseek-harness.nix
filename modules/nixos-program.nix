{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.dsh;
  mkDsh = import ../lib/mk-dsh.nix;
in

{
  imports = [ ./shared-profile-options.nix ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (mkDsh {
        package = cfg.package;
        profiles = cfg.profiles;
        agentPresets = cfg.agentPresets;
        defaultProfile = cfg.defaultProfile;
        patch = cfg.patch;
      })
    ];

    environment.variables = lib.mkIf (cfg.home != null) {
      DSH_HOME = cfg.home;
    };
  };
}
