{
  scope,
}:
let
  hasSuffix =
    suffix: string:
    let
      stringLength = builtins.stringLength string;
      suffixLength = builtins.stringLength suffix;
    in
    suffixLength <= stringLength
    && builtins.substring (stringLength - suffixLength) suffixLength string == suffix;

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
      templateEntries = package.passthru.profileTemplates.entries or { };
      managedProfiles = builtins.filter (hasSuffix "/.nix-managed") (builtins.attrNames templateEntries);
    in
    {
      inherit name;
      package = package.pname;
      defaultProfile = package.passthru.defaultProfileName or null;
      profiles = map (
        entry:
        builtins.substring 0 (builtins.stringLength entry - builtins.stringLength "/.nix-managed") entry
      ) managedProfiles;
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
