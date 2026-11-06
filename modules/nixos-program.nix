{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dsh;
  mkDsh = import ../lib/mk-dsh.nix;
  desktopPackage = import ../lib/mk-dsh-desktop.nix { inherit lib pkgs cfg; };
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
          runtime = if cfg.desktop.enable then desktopPackage.passthru.dshRuntime or null else null;
        })
      ];

      environment.variables = lib.mkIf (cfg.home != null) {
        DSH_HOME = cfg.home;
      };
    })
  ];
}
