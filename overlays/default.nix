final: _prev:
let
  dshLib = import ../lib { inherit (final) lib; };
  dsh = final.lib.makeScope final.newScope (
    self:
    let
      helpers = dshLib.scope final self;
      # Inject bundles into the directory scope because package arguments resolve there.
      directoryPackages =
        (final.lib.packagesFromDirectoryRecursive {
          callPackage = self.callPackage;
          newScope = self.newScope;
          directory = ../pkgs;
        }).overrideScope
          (
            _: dirPrev: {
              bundles = dirPrev.bundles.overrideScope (
                _: prev:
                let
                  generated = dshLib.optionalBundles final self;
                  collisions = final.lib.attrNames (final.lib.intersectAttrs generated prev);
                in
                final.lib.throwIf (collisions != [ ])
                  "dsh optional bundles collide with pkgs/bundles: ${final.lib.concatStringsSep ", " collisions}"
                  (generated // final.lib.mapAttrs (_: message: throw message) helpers.removedBundles)
              );
            }
          );
    in
    # The wrapped fetchPnpmDeps stays in the dsh scope so unrelated pnpm
    # packages retain their release-age policy.
    helpers
    // {
      helpers.buildBundle = helpers.buildDshBundle;
      mkDshBundle = helpers.buildDshBundle;
      dsh-desktop = self.dsh-desktop-official;
    }
    // directoryPackages
  );
in
{
  inherit dsh;
}
