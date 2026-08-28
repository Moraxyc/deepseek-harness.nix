final: prev:
let
  compatiblePnpm =
    if prev.lib.versionOlder prev.pnpm_11.version "11.22.0" then
      prev.pnpm_11.overrideAttrs (_oldAttrs: {
        version = "11.22.0";
        src = prev.fetchurl {
          url = "https://registry.npmjs.org/pnpm/-/pnpm-11.22.0.tgz";
          hash = "sha256-V6l+byOj+v/AMVOk74x3CgVSYSuGQK6+Ob/dV1TQ69w=";
        };
      })
    else
      prev.pnpm_11;
  buildDshBundle = import ../lib/mk-dsh-bundle.nix {
    inherit (final)
      buildNpmPackage
      jq
      lib
      nodejs
      nodejs-slim
      stdenvNoCC
      writeShellApplication
      writers
      ;
    pnpm_11 = compatiblePnpm;
  };
  dsh = final.lib.makeScope final.newScope (
    self:
    {
      inherit buildDshBundle;
      pnpm_11 = compatiblePnpm;
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
