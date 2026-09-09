{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dsh;
  common = import ./service-common.nix { inherit lib pkgs; };
  unitName = "dsh-web";
in
{
  imports = [ ./shared-profile-options.nix ];

  options.services.dsh = common.mkOptions {
    inherit cfg config;
    enableName = "the DeepSeek Harness user web service";
    dataDirDefault =
      if config.programs.dsh.home != null then
        config.programs.dsh.home
      else
        "${config.home.homeDirectory}/.dsh";
    dataDirDefaultText = lib.literalExpression ''
      if config.programs.dsh.home != null then
        config.programs.dsh.home
      else
        "''${config.home.homeDirectory}/.dsh"
    '';
    dataDirDescription = "Directory used as `DSH_HOME`; defaults to the same location the dsh CLI uses.";
    workspaceDescription = "Working directory used by the unit.";
    autoStartDescription = "Start the service with `default.target`.";
  };

  config = lib.mkIf cfg.enable {
    systemd.user.tmpfiles.rules = common.mkTmpfilesRules {
      directories = [
        cfg.dataDir
        cfg.workspace
      ];
      owner = "- -";
    };

    systemd.user.services.${unitName} = {
      Unit = {
        Description = "DeepSeek Harness web service";
        After = [ "network.target" ];
      };

      Service = common.mkServiceConfig { inherit cfg; } // {
        Environment = [
          "DSH_HOME=${cfg.dataDir}"
        ]
        ++ lib.mapAttrsToList (name: value: "${name}=${value}") cfg.environment;
      };

      Install = {
        WantedBy = lib.optionals cfg.autoStart [ "default.target" ];
      };
    };
  };
}
