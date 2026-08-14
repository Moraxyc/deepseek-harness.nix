{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        default = pkgs.dsh;
        inherit (pkgs)
          dsh
          dsh-kernel
          dsh-workspace
          ;
      };

      legacyPackages = {
        inherit (pkgs) bundles presets;
      };

      apps.default = {
        type = "app";
        program = "${pkgs.dsh}/bin/dsh";
      };
    };
}
