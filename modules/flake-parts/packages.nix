{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      dsh = pkgs.dsh;
      docs-site = pkgs.callPackage ../../pkgs/docs-site/package.nix { };
      packages = {
        default = dsh.dsh;
        inherit (dsh)
          dsh
          dsh-desktop
          dsh-desktop-official
          dsh-desktop-unofficial
          dsh-runtime
          dsh-workspace
          ;
        inherit docs-site;
      };

      legacyPackages = {
        inherit (dsh) bundles presets;
        fetchrixPackages = import ../../lib/fetchrix-packages.nix { inherit lib dsh; };
        tools = import ../../scripts { inherit pkgs; };
        inherit bundleCompositions bundleProbes;
        allBundleCompositions = pkgs.linkFarm "all-compositions" (
          pkgs.lib.mapAttrsToList (name: drv: {
            inherit name;
            path = drv;
          }) bundleCompositions
        );
        inherit ciPackages ciTargets;
      };
      isBuildable =
        package:
        lib.isDerivation package
        && !((package.meta or { }).broken or false)
        && lib.meta.availableOn pkgs.stdenv.hostPlatform package;

      buildablePackages = lib.filterAttrs (
        name: package: name != "default" && name != "docs-site" && isBuildable package
      ) packages;
      buildableBundles = lib.filterAttrs (_: package: isBuildable package) (
        builtins.removeAttrs legacyPackages.bundles (builtins.attrNames dsh.removedBundles)
      );
      buildablePresets = lib.filterAttrs (_: package: isBuildable package) legacyPackages.presets;
      bundleNames = lib.attrNames buildableBundles;
      # Bundles the installation carries need no composition of their own.
      bundleCompositionNames = lib.filter (
        name: !(buildableBundles.${name}.passthru.dshInstallation or false)
      ) bundleNames;
      composeBundle =
        name:
        (dsh.dsh.withProfiles {
          test.bundles = b: [ b.${name} ];
        }).override
          { defaultProfile = "nix-test"; };
      bundleCompositions = lib.genAttrs bundleCompositionNames composeBundle;
      # Every bundle composed without its install check, for tools.dsh-bundle-probe.
      bundleProbes = lib.genAttrs bundleNames (
        name: (composeBundle name).overrideAttrs { dontDshBundleCheck = true; }
      );
      ciPackages = {
        packages = buildablePackages;
        bundles = buildableBundles;
        presets = buildablePresets;
      };
      ciTargets = ciPackages // {
        inherit bundleCompositions;
      };
    in
    {
      inherit packages legacyPackages;

      apps.default = {
        type = "app";
        program = lib.getExe dsh.dsh;
        meta.description = dsh.dsh.meta.description;
      };

      apps.dsh-desktop = {
        type = "app";
        program = lib.getExe dsh.dsh-desktop;
        meta.description = dsh.dsh-desktop.meta.description;
      };

      apps.dsh-desktop-official = {
        type = "app";
        program = lib.getExe dsh.dsh-desktop-official;
        meta.description = dsh.dsh-desktop-official.meta.description;
      };

    };
}
