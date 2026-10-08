{
  lib,
  validateDshBundle,
}:

let
  validateBundle = bundle: validateDshBundle { inherit bundle; };

  validateBundles = bundles: map validateBundle bundles;
in
{
  packagesFromScope = scope: lib.attrValues (scope.packages scope);

  inherit validateBundles;

  composeBundles =
    {
      base,
      defaults,
      profiles,
    }:
    let
      bundles = [
        base
      ]
      ++ defaults
      ++ lib.concatMap (profile: profile.bundles) (lib.attrValues profiles);
    in
    lib.unique (validateBundles bundles);

  runtimeDeps =
    bundles:
    lib.unique (lib.concatLists (map (bundle: bundle.passthru.runtimeDeps) (validateBundles bundles)));
}
