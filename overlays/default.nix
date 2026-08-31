final: prev:
let
  # Keep pnpm from downloading a package manager version declared by an
  # upstream project. Upstream release lockfiles are the source of truth, so
  # their pinned dependencies must not be blocked by pnpm's release-age default.
  wrapFetchPnpmDeps =
    base:
    let
      wrapped = prev.lib.makeOverridable (
        args:
        base (
          args
          // {
            prePnpmInstall = (args.prePnpmInstall or "") + ''
              export pnpm_config_manage_package_manager_versions=false
              export pnpm_config_minimum_release_age=0
            '';
          }
        )
      );
    in
    wrapped
    // {
      override = overrides: wrapFetchPnpmDeps (base.override overrides);
      overrideDerivation = f: wrapFetchPnpmDeps (base.overrideDerivation f);
    };
  fetchPnpmDeps = wrapFetchPnpmDeps prev.fetchPnpmDeps;
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
  inherit dsh fetchPnpmDeps importPnpmLock;
}
