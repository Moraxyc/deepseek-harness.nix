{ ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      bundleName = "dsh-bundle-helper-check";
      bundleSource = ./fixtures/bundle-helper-npm;
      bundle = pkgs.dsh.helpers.buildBundle (_finalAttrs: {
        pname = bundleName;
        version = "1.0.0";

        src = bundleSource;
        npmDeps = pkgs.importNpmLock { npmRoot = bundleSource; };
        npmConfigHook = pkgs.importNpmLock.npmConfigHook;
        dontBuild = true;

        postInstall = ''
          packageRoot="$out/lib/node_modules/${bundleName}"
          test -f "$packageRoot/dist/index.js"
          test -f "$packageRoot/node_modules/@sinclair/typebox/package.json"
          test ! -e "$packageRoot/node_modules/@standard-schema/spec"
        '';

        meta.description = "External bundle helper regression check";
      });
    in
    {
      checks.dsh-bundle-helper = bundle;
    };
}
