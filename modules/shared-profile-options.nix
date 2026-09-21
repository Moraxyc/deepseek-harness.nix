{
  config,
  lib,
  pkgs,
  ...
}:
let
  profileOptions = import ./profile-options.nix {
    inherit lib;
    desktopProfile =
      if config.programs.dsh.desktop.enable then config.programs.dsh.desktop.profile else null;
  };
in

{
  options.programs.dsh = {
    enable = lib.mkEnableOption "the DeepSeek Harness dsh CLI with declarative profiles";

    package = lib.mkPackageOption pkgs.dsh "dsh" { };

    desktop = {
      enable = lib.mkEnableOption "the DeepSeek Harness desktop application";

      package = lib.mkPackageOption pkgs.dsh "dsh-desktop-official" { };

      profile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Materialized profile from programs.dsh.profiles used by the official
          desktop. Leave unset to use the upstream desktop profile.
        '';
      };
    };

    home = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/.local/share/dsh";
      description = "Directory exported as `DSH_HOME`. Leave unset to use dsh's `$HOME/.dsh` default.";
    };

    patch = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.attrs);
      default = null;
      example = lib.literalExpression ''
        [
          {
            id = "agent-default-model";
            config = {
              provider = "deepseek-official";
              model = "deepseek-flash";
            };
          }
        ]
      '';
      description = ''
        Home-level Cordis patch layer managed at
        `$DSH_HOME/cordis.patch.yml`. Leave unset to keep the file unmanaged.
      '';
    };

    agentPresets = profileOptions.mkAgentPresetsOption { };

    profiles = profileOptions.mkProfilesOption { };

    defaultProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Profile passed by default when the command does not receive an
        explicit `--profile`; use the materialized name, such as
        `config.programs.dsh.profiles.tui.materializedName`.
      '';
    };
  };
}
