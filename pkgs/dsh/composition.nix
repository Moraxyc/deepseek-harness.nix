{ lib }:

let
  packageLabel = bundle: bundle.pname or bundle.name or "<unknown>";

  validateBundle =
    bundle:
    let
      passthru = bundle.passthru or { };
      label = packageLabel bundle;
      runtimeDeps = passthru.runtimeDeps or [ ];
    in
    if !(passthru ? dshBundle) || passthru.dshBundle != true then
      throw "dsh composition: ${label} is not created by mkDshBundle"
    else if !(passthru ? dshBundleHelper) || passthru.dshBundleHelper != "buildDshBundle" then
      throw "dsh composition: ${label} does not use the buildDshBundle protocol"
    else if !lib.isList runtimeDeps then
      throw "dsh composition: ${label} must expose passthru.runtimeDeps as a list"
    else
      bundle;

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
    # Preserve each bundle's declared runtime dependency order; callers control
    # bundle precedence before flattening this list.
    lib.unique (lib.concatLists (map (bundle: bundle.passthru.runtimeDeps) (validateBundles bundles)));
}
