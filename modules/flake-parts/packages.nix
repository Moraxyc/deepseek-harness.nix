{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      dsh = pkgs.dsh;
      docs-site = pkgs.callPackage ../../pkgs/docs-site/package.nix { };
      importPnpmLock = dsh.importPnpmLock;
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
        ciPackageAttrs = {
          packages = packageAttrs;
          bundles = bundleAttrs;
          presets = presetAttrs;
          inherit bundleDependents;
        };
      };

      packageNames = lib.attrNames (
        lib.filterAttrs (name: package: name != "default" && lib.isDerivation package) packages
      );
      bundleNames = lib.attrNames (
        lib.filterAttrs (_: package: lib.isDerivation package) legacyPackages.bundles
      );
      presetNames = lib.attrNames (
        lib.filterAttrs (_: package: lib.isDerivation package) legacyPackages.presets
      );
      packageAttrs = lib.genAttrs packageNames (name: ".#${name}");
      bundleAttrs = lib.genAttrs bundleNames (name: ".#bundles.${name}");
      presetAttrs = lib.genAttrs presetNames (name: ".#presets.${name}");
      usesBundle =
        package: bundlePname:
        lib.any (bundle: (bundle.pname or bundle.name or null) == bundlePname) (
          (package.passthru or { }).composedBundles or [ ]
        );
      bundleDependents = lib.genAttrs bundleNames (
        bundleName:
        let
          bundlePname = legacyPackages.bundles.${bundleName}.pname;
          affectedPackages = lib.filter (name: usesBundle packages.${name} bundlePname) packageNames;
          affectedPresets = lib.filter (
            name: usesBundle legacyPackages.presets.${name} bundlePname
          ) presetNames;
        in
        (map (name: packageAttrs.${name}) affectedPackages)
        ++ lib.optional (lib.elem "dsh" affectedPackages) packageAttrs.dsh-desktop
        ++ map (name: presetAttrs.${name}) affectedPresets
      );
    in
    {
      # Keep build helpers and runtime dependencies out of the public package set.
      inherit packages legacyPackages;

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
