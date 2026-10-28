{
  lib,
  gitMinimal,
  gh,
  nodejs-slim,
  buildDshBundle,
  dsh-kernel,
  dsh-cua-native,
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

      runtimeDeps =
        lib.optionals
          (lib.elem packageName [
            "@deepseek-ai/dsh-experimental-tool-worktree"
            "@deepseek-ai/dsh-experimental-forge-bundle"
          ])
          [
            gitMinimal
            nodejs-slim
          ]
        ++ lib.optional (packageName == "@deepseek-ai/dsh-experimental-forge-bundle") gh;

      passthru = lib.optionalAttrs entry.requiresWeb {
        requiresWeb = true;
      };

      meta = {
        inherit (entry) description;
        descriptions.zh-CN = entry.descriptionZh;
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
    });
in
lib.mapAttrs' (
  packageName: entry: lib.nameValuePair entry.attr (mkBundle packageName entry)
) manifest
