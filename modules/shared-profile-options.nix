{
  lib,
  pkgs,
  ...
}:
let
  profileOptions = import ./profile-options.nix { inherit lib; };
in

{
  options.programs.dsh = {
    enable = lib.mkEnableOption "the DeepSeek Harness dsh CLI with declarative profiles";

    package = lib.mkPackageOption pkgs.dsh "dsh" { };

    home = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/.local/share/dsh";
      description = "Directory exported as `DSH_HOME`. Leave unset to use dsh's `$HOME/.dsh` default.";
    };

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
