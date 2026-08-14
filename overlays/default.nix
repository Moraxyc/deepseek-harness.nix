final: _prev:
let
  buildDshBundle = import ../lib/mk-dsh-bundle.nix {
    inherit (final)
      buildNpmPackage
      lib
      nodejs
      nodejs-slim
      stdenvNoCC
      ;
  };
  packages = final.lib.packagesFromDirectoryRecursive {
    callPackage = final.callPackage;
    newScope = final.newScope;
    directory = ../pkgs;
  };
in
{
  inherit buildDshBundle;
  mkDshBundle = buildDshBundle;

  inherit (packages)
    dsh
    dsh-kernel
    bundles
    presets
    ;
}
