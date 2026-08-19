{
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      dsh = pkgs.dsh;
      docs-site = pkgs.callPackage ../../pkgs/docs-site/package.nix { };
      importPnpmLock = dsh.importPnpmLock;
    in
    {
      packages = lib.filterAttrs (_: package: lib.isDerivation package && package ? meta) dsh // {
        default = dsh.dsh;
        inherit docs-site;
      };

      legacyPackages = {
        inherit (dsh) bundles presets;
        inherit importPnpmLock;
      };

      apps.default = {
        type = "app";
        program = "${dsh.dsh}/bin/dsh";
        meta.description = dsh.dsh.meta.description;
      };

      apps.dsh-desktop = {
        type = "app";
        program = "${dsh.dsh-desktop}/bin/dsh-desktop";
        meta.description = dsh.dsh-desktop.meta.description;
      };

    };
}
