{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.programs.dsh = {
    enable = lib.mkEnableOption "the DeepSeek Harness dsh CLI with declarative profiles";

    package = lib.mkPackageOption pkgs "dsh" { };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            bundles = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = ''
                dsh bundle packages for this profile, e.g. `pkgs.bundles.optional.tui`.
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
          tui.bundles = [ pkgs.bundles.optional.tui ];
        }
      '';
      description = ''
        dsh profiles copied to `$DSH_HOME/profiles/<name>` (default
        `~/.dsh/profiles`) on first use. Existing profile files are not
        overwritten.
      '';
    };
  };

  config = lib.mkIf config.programs.dsh.enable {
    environment.systemPackages = [
      (config.programs.dsh.package.withProfiles config.programs.dsh.profiles)
    ];
  };

}
