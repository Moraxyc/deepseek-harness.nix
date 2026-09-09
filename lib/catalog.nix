{
  scope,
}:
let
  packageNames =
    attrs:
    builtins.sort (a: b: a < b) (
      builtins.filter (name: attrs.${name} ? pname) (builtins.attrNames attrs)
    );

  bundleInfo = name: package: {
    inherit name;
    package = package.pname;
    version = package.version or null;
    description = package.meta.description or null;
    descriptionZh = package.meta.descriptions.zh-CN or package.meta.description or null;
    homepage = package.meta.homepage or null;
  };

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
      description = package.meta.description or null;
      descriptionZh = package.meta.descriptions.zh-CN or package.meta.description or null;
      homepage = package.meta.homepage or null;
    };

in
{
  bundles = map (name: bundleInfo name scope.bundles.${name}) (packageNames scope.bundles);
  presets = map (name: presetInfo name scope.presets.${name}) (packageNames scope.presets);
}
