{ ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      bundleName = "dsh-bundle-helper-check";
      bundle = pkgs.dsh.helpers.buildBundle (_finalAttrs: {
        pname = bundleName;
        version = "1.0.0";

        src = null;
        npmDeps = null;
        dontUnpack = true;
        dontPatch = true;
        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          packageRoot="$out/lib/node_modules/${bundleName}"
          mkdir -p "$packageRoot"
          cp ${
            pkgs.writeText "package.json" (
              builtins.toJSON {
                name = bundleName;
                version = "1.0.0";
                dsh.bundle.patch = "./cordis.patch.yml";
              }
            )
          } "$packageRoot/package.json"
          cp ${pkgs.writeText "cordis.patch.yml" "[]\n"} "$packageRoot/cordis.patch.yml"

          runHook postInstall
        '';

        meta.description = "External bundle helper regression check";
      });
    in
    {
      checks.dsh-bundle-helper = bundle;
    };
}
