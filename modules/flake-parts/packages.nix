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
          dsh-desktop-official
          dsh-desktop-unofficial
          dsh-kernel
          dsh-workspace
          ;
        inherit docs-site;
      };

      legacyPackages = {
        inherit (dsh) bundles presets;
        inherit importPnpmLock;
        inherit bundleCompositions;
        ciPackageAttrs = {
          packages = packageAttrs;
          bundles = bundleAttrs;
          presets = presetAttrs;
          bundleCompositions = bundleCompositionAttrs;
          inherit bundleDependents;
        };
      };
      isBuildable = package: lib.isDerivation package && !((package.meta or { }).broken or false);

      packageNames = lib.attrNames (
        lib.filterAttrs (name: package: name != "default" && isBuildable package) packages
      );
      bundleNames = lib.attrNames (
        lib.filterAttrs (_: package: isBuildable package) legacyPackages.bundles
      );
      presetNames = lib.attrNames (
        lib.filterAttrs (_: package: isBuildable package) legacyPackages.presets
      );
      packageAttrs = lib.genAttrs packageNames (name: ".#${name}");
      bundleAttrs = lib.genAttrs bundleNames (name: ".#bundles.${name}");
      presetAttrs = lib.genAttrs presetNames (name: ".#presets.${name}");
      bundleKeyOf = bundle: bundle.pname or bundle.name or null;
      defaultBundleKeys = map bundleKeyOf dsh.dsh.passthru.composedBundles;
      bundleCompositionNames = lib.filter (
        name: !(lib.elem (bundleKeyOf legacyPackages.bundles.${name}) defaultBundleKeys)
      ) bundleNames;
      bundleCompositionAttrs = lib.genAttrs bundleCompositionNames (name: ".#bundleCompositions.${name}");
      bundleCompositions = lib.genAttrs bundleCompositionNames (
        name:
        (dsh.dsh.withProfiles {
          test.bundles = b: [ b.${name} ];
        }).override
          { defaultProfile = "nix-test"; }
      );
      usesBundle =
        package: bundleKey:
        lib.any (bundle: bundleKeyOf bundle == bundleKey) (
          (package.passthru or { }).composedBundles or [ ]
        );
      bundleDependents = lib.genAttrs bundleNames (
        bundleName:
        let
          bundleKey = bundleKeyOf legacyPackages.bundles.${bundleName};
          affectedPackages = lib.filter (name: usesBundle packages.${name} bundleKey) packageNames;
          affectedPresets = lib.filter (
            name: usesBundle legacyPackages.presets.${name} bundleKey
          ) presetNames;
        in
        (map (name: packageAttrs.${name}) affectedPackages)
        ++ lib.optional (lib.elem "dsh" affectedPackages) packageAttrs.dsh-desktop
        ++ lib.optional (lib.elem "dsh" affectedPackages) packageAttrs.dsh-desktop-official
        ++ lib.optional (lib.elem "dsh" affectedPackages) packageAttrs.dsh-desktop-unofficial
        ++ map (name: presetAttrs.${name}) affectedPresets
      );
    in
    {
      # Keep build helpers and runtime dependencies out of the public package set.
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
