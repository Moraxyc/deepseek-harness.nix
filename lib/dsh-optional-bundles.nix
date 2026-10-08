# Upstream's OPTIONAL_BUNDLES resolve from every profile but are selected by none.
{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
}:
let
  manifest = lib.importJSON ../pkgs/dsh-workspace/optional-bundles.json;

  mkBundle =
    packageName: entry:
    buildDshBundle.fromWorkspace (_finalAttrs: {
      inherit dsh-kernel dsh-workspace packageName;

      inherit (entry) pname;

      linkKernelNodeModules = dsh-kernel;

      passthru = lib.optionalAttrs entry.requiresWeb {
        requiresWeb = true;
      };

      meta = {
        inherit (entry) description;
        descriptions.zh-CN = entry.descriptionZh;
        homepage = "https://github.com/deepseek-ai/deepseek-harness";
        license = lib.licenses.mit;
        platforms = lib.platforms.unix;
      };
    });
in
lib.mapAttrs' (
  packageName: entry: lib.nameValuePair entry.attr (mkBundle packageName entry)
) manifest
