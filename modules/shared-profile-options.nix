{
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
                Their package manifests are resolved during the build in list
                order and applied after the shared `@deepseek-ai/dsh-base`
                layer; later bundles override earlier Cordis configuration.
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

            mode = lib.mkOption {
              type = lib.types.enum [
                "managed"
                "mutable"
              ];
              default = "managed";
              description = ''
                How Nix treats this profile after it is first materialized.

                - `managed`: Nix keeps the profile in sync with the
                  configuration and restores any local change on the next
                  activation or `dsh` run.
                - `mutable`: Nix only seeds the profile when its directory
                  does not exist yet; afterwards the user manages the profile
                  with `dsh` and Nix leaves it untouched.
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
}
