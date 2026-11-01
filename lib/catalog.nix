{
  lib,
  scope,
}:
let
  packageNames =
    attrs:
    lib.attrNames (
      lib.filterAttrs (_: package: package ? pname && !(package.meta.broken or false)) attrs
    );

  metaInfo =
    package:
    let
      meta = package.meta or { };
      descriptions = meta.descriptions or { };
    in
    {
      description = meta.description or null;
      descriptionZh = descriptions.zh-CN or meta.description or null;
      descriptionJa = descriptions.ja or meta.description or null;
      homepage = meta.homepage or null;
    };

  bundleInfo =
    name: package:
    {
      inherit name;
      package = package.pname;
      version = package.version or null;
    }
    // metaInfo package;

  presetInfo =
    name: package:
    let
      config = package.passthru.config or { };
    in
    {
      inherit name;
      package = package.pname;
      defaultProfile = config.defaultProfile or null;
      profiles = package.passthru.profileNames or [ ];
      bundles = map (bundle: bundle.pname or bundle.name) (package.passthru.composedBundles or [ ]);
    }
    // metaInfo package;

in
{
  bundles = map (name: bundleInfo name scope.bundles.${name}) (
    packageNames (builtins.removeAttrs scope.bundles (builtins.attrNames scope.removedBundles))
  );
  presets = map (name: presetInfo name scope.presets.${name}) (packageNames scope.presets);
}
