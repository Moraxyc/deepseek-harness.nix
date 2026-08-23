{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        settings.formatter = {
          prettier.excludes = [
            "**/pnpm-lock.json"
          ];
        };

        programs = {
          nixfmt.enable = true;
          shellcheck.enable = true;
          prettier.enable = true;
        };
      };
    };
}
