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
