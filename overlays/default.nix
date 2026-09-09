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
  # `pnpm deploy` injects workspace dependencies only from 11.22.0 on
  # (pnpm/pnpm#13754); older releases link back into the source workspace and
  # break the self-contained bundle. nixpkgs pins such as nixos-26.05 can ship
  # an older pnpm 11, so build the minimum from the npm tarball in that case,
  # under a dsh-only name so nixpkgs' generic pnpm_11 stays untouched.
  dshPnpmMinVersion = "11.22.0";
  dshPnpm =
    let
      pnpm =
        if prev.lib.versionAtLeast prev.pnpm_11.version dshPnpmMinVersion then
          prev.pnpm_11
        else
          prev.pnpm_11.override {
            version = dshPnpmMinVersion;
            hash = "sha256-V6l+byOj+v/AMVOk74x3CgVSYSuGQK6+Ob/dV1TQ69w=";
          };
    in
    assert prev.lib.assertMsg (prev.lib.versionAtLeast pnpm.version dshPnpmMinVersion)
      "dsh: pnpm ${pnpm.version} is older than the required ${dshPnpmMinVersion}";
    pnpm;
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
    inherit dshPnpm;
  };
  dsh = final.lib.makeScope final.newScope (
    self:
    {
      # Only the dsh package set gets the release-age opt-out. Exporting the
      # wrapped fetcher at the nixpkgs top level would change every unrelated
      # pnpm package.
      inherit buildDshBundle fetchPnpmDeps;
      inherit dshPnpm;
      helpers.buildBundle = buildDshBundle;
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
