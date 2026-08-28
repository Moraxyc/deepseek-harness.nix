final: _prev:
let
  buildDshBundle = import ../lib/mk-dsh-bundle.nix {
    inherit (final)
      buildNpmPackage
      jq
      lib
      nodejs
      nodejs-slim
      pnpm_11
      stdenvNoCC
      writeShellApplication
      writers
      ;
  };
  dsh = final.lib.makeScope final.newScope (
    self:
    {
      inherit buildDshBundle;
      helpers.buildBundle = buildDshBundle;
      mkDshBundle = buildDshBundle;
    }
    // final.lib.packagesFromDirectoryRecursive {
      callPackage = self.callPackage;
      newScope = self.newScope;
      directory = ../pkgs;
    }
  );
  importPnpmLock = dsh.importPnpmLock;
in
{
  inherit dsh importPnpmLock;
}
