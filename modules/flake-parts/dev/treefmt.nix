{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = { ... }: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = {
        nixfmt.enable = true;
        shellcheck.enable = true;
        prettier = {
          enable = true;
          excludes = [ "pkgs/**/pnpm-lock.json" ];
        };
      };
    };
  };
}
