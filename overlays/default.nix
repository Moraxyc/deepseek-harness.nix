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
  dsh = final.lib.makeScope final.newScope (
    self:
    {
      inherit buildDshBundle;
      mkDshBundle = buildDshBundle;
    }
    // final.lib.packagesFromDirectoryRecursive {
      callPackage = self.callPackage;
      newScope = self.newScope;
      directory = ../pkgs;
    }
  );
in
{
  inherit dsh;
}
