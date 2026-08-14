{ dsh-src }:
final: _prev:
let
  packages = final.lib.packagesFromDirectoryRecursive {
    callPackage = final.callPackage;
    newScope = final.newScope;
    directory = ../pkgs;
  };
in
{
  inherit dsh-src;

  inherit (packages)
    dsh
    dsh-kernel
    bundles
    presets
    ;
}
