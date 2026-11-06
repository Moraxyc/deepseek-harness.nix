{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dsh;
  inherit (pkgs.dsh) mkDsh;
  desktopPackage = pkgs.dsh.mkDshDesktop cfg;
in

{
  imports = [ ./shared-profile-options.nix ];

  config = lib.mkMerge [
    (lib.mkIf cfg.desktop.enable {
      environment.systemPackages = [ desktopPackage ];
    })
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        (mkDsh {
          package = cfg.package;
          profiles = cfg.profiles;
          agentPresets = cfg.agentPresets;
          defaultProfile = cfg.defaultProfile;
          desktopProfile = if cfg.desktop.enable then cfg.desktop.profile else null;
          patch = cfg.patch;
        })
      ];

      environment.variables = lib.mkIf (cfg.home != null) {
        DSH_HOME = cfg.home;
      };
    })
  ];
}
