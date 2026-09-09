{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      dsh = pkgs.dsh;
      docs-site = pkgs.callPackage ../../pkgs/docs-site/package.nix { };
      importPnpmLock = dsh.importPnpmLock;
    in
    {
      # Keep build helpers and runtime dependencies out of the public package set.
      packages = {
        default = dsh.dsh;
        inherit (dsh)
          dsh
          dsh-desktop
          dsh-kernel
          dsh-workspace
          ;
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
