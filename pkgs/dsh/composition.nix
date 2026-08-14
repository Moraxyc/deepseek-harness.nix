{ lib }:

{
  packagesFromScope = scope: lib.attrValues (scope.packages scope);

  composeBundles =
    {
      base,
      defaults,
      extraPlugins,
      profiles,
    }:
    lib.unique (
      [ base ]
      ++ defaults
      ++ extraPlugins
      ++ lib.concatMap (profile: profile.bundles) (lib.attrValues profiles)
    );

  bundleDeps =
    bundles:
    lib.concatMap (
      bundle:
      map (rel: {
        name = rel;
        value = bundle.version;
      }) bundle.passthru.dshBundles
    ) bundles;

  runtimeDeps =
    bundles:
    lib.unique (
      lib.concatLists (
        map (bundle: bundle.passthru.runtimeDeps or [ ]) bundles
      )
    );

  dshBundles =
    kernel: bundles:
    lib.concatLists (
      [ kernel.passthru.dshBundles ]
      ++ map (bundle: bundle.passthru.dshBundles) bundles
    );
}
