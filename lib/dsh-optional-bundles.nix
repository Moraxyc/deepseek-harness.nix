{
  lib,
  buildDshBundle,
  dsh-runtime,
  dsh-cua-native,
  dshSources,
}:
let
  manifest = lib.importJSON dshSources.dsh-workspace.artifacts."optional-bundles.json";

  mkBundle =
    packageName: entry:
    buildDshBundle.fromInstallation {
      inherit packageName;
      inherit (entry) pname;
      installation = dsh-runtime;

      passthru = lib.optionalAttrs entry.requiresWeb {
        requiresWeb = true;
      };

      meta = {
        inherit (entry) description;
        descriptions.zh-CN = entry.descriptionZh;
        descriptions.ja = entry.descriptionJa;
        homepage = "https://github.com/deepseek-ai/deepseek-harness";
        license = lib.licenses.mit;
        platforms =
          if packageName == "@deepseek-ai/dsh-cua-bundle" then
            dsh-cua-native.meta.platforms
          else if entry.platforms == [ ] then
            lib.platforms.unix
          else
            lib.concatMap (platform: lib.platforms.${platform}) entry.platforms;
      };
    };
in
lib.mapAttrs' (
  packageName: entry: lib.nameValuePair entry.attr (mkBundle packageName entry)
) manifest
