{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.programs.dsh = {
    enable = lib.mkEnableOption "the DeepSeek Harness dsh CLI with declarative profiles";

    package = lib.mkPackageOption pkgs.dsh "dsh" { };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            bundles = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = ''
                dsh bundle packages for this profile, e.g. `pkgs.dsh.bundles.tui`.
                Their `passthru.dshBundles` are added to the shared
                `@deepseek-ai/dsh-base` layer and the installed package.
              '';
            };

            patch = lib.mkOption {
              type = lib.types.lines;
              default = lib.generators.toYAML { } [ ];
              description = ''
                The profile's `cordis.patch.yml` layer, applied after bundle
                layers.
              '';
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          tui.bundles = [ pkgs.dsh.bundles.tui ];
        }
      '';
      description = ''
        Nix-managed dsh profiles. A profile named `tui` is materialized as
        `$DSH_HOME/profiles/nix-tui` (default `~/.dsh/profiles/nix-tui`).
        Unmanaged profile directories are never taken over.
      '';
    };

    defaultProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Profile passed by default when the command does not receive an
        explicit `--profile`; use the materialized name, such as `nix-tui`.
      '';
    };
  };

  config = lib.mkIf config.programs.dsh.enable {
    environment.systemPackages = [
      ((config.programs.dsh.package.withProfiles config.programs.dsh.profiles).override {
        defaultProfile = config.programs.dsh.defaultProfile;
      })
    ];
  };

}
