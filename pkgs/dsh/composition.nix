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
    else if !(passthru ? dshBundles) || !lib.isList passthru.dshBundles then
      throw "dsh composition: ${label} must expose passthru.dshBundles as a list"
    else if !lib.all lib.isString passthru.dshBundles then
      throw "dsh composition: ${label} has a non-string passthru.dshBundles entry"
    else if !lib.isList runtimeDeps then
      throw "dsh composition: ${label} must expose passthru.runtimeDeps as a list"
    else
      bundle;

  validateBundles = bundles: map validateBundle bundles;

  bundleEntries =
    bundles:
    lib.concatMap (
      bundle:
      map (name: {
        inherit name;
        value = bundle.version;
      }) bundle.passthru.dshBundles
    ) (validateBundles bundles);

  versionsByName =
    entries:
    lib.foldl' (
      groups: entry:
      let
        versions = if builtins.hasAttr entry.name groups then builtins.getAttr entry.name groups else [ ];
      in
      groups // { "${entry.name}" = versions ++ [ entry.value ]; }
    ) { } entries;

  bundleDeps =
    bundles:
    let
      groups = versionsByName (bundleEntries bundles);
      conflictingNames = lib.filter (name: lib.length (lib.unique (builtins.getAttr name groups)) > 1) (
        lib.attrNames groups
      );
      conflictDetails = map (
        name: "${name}: ${lib.concatStringsSep ", " (map toString (builtins.getAttr name groups))}"
      ) conflictingNames;
    in
    if conflictingNames != [ ] then
      throw "dsh composition: conflicting bundle versions (${lib.concatStringsSep "; " conflictDetails})"
    else
      map (name: {
        inherit name;
        value = builtins.head (builtins.getAttr name groups);
      }) (lib.attrNames groups);
in
{
  packagesFromScope = scope: lib.attrValues (scope.packages scope);

  inherit validateBundles;

  composeBundles =
    {
      base,
      defaults,
      extraPlugins,
      profiles,
    }:
    let
      bundles = [
        base
      ]
      ++ defaults
      ++ extraPlugins
      ++ lib.concatMap (profile: profile.bundles) (lib.attrValues profiles);
    in
    lib.unique (validateBundles bundles);

  inherit bundleDeps;

  runtimeDeps =
    bundles:
    lib.unique (lib.concatLists (map (bundle: bundle.passthru.runtimeDeps) (validateBundles bundles)));

  dshBundles =
    kernel: bundles:
    lib.concatLists (
      [ kernel.passthru.dshBundles ] ++ map (bundle: bundle.passthru.dshBundles) (validateBundles bundles)
    );
}
