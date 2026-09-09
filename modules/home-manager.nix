{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.dsh;
  mkDsh = import ../lib/mk-dsh.nix;
  composed = mkDsh {
    package = cfg.package;
    profiles = cfg.profiles;
    agentPresets = cfg.agentPresets;
    defaultProfile = cfg.defaultProfile;
    patch = cfg.patch;
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
