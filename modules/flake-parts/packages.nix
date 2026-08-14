{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      dsh = pkgs.dsh;
    in
    {
      packages = {
        default = dsh.dsh;
        inherit (dsh)
          dsh-kernel
          dsh-workspace
          ;
        inherit (dsh)
          dsh
          ;
      };

      legacyPackages = {
        inherit (dsh) bundles presets;
      };

      apps.default = {
        type = "app";
        program = "${dsh.dsh}/bin/dsh";
      };
    };
}
