final: prev:
let
  # `pnpm deploy` injects workspace dependencies only from 11.22.0 on
  # (pnpm/pnpm#13754); older releases link back into the source workspace and
  # break the self-contained bundle. This is a requirement of the deploy step,
  # not of DSH as a whole, so keep it under a deploy-specific name and leave
  # nixpkgs' pnpm_11 available to bundles that only fetch or build.
  pnpmWorkspaceDeployMinVersion = "11.22.0";
  pnpmWorkspaceDeploy =
    let
      pnpm =
        if prev.lib.versionAtLeast prev.pnpm_11.version pnpmWorkspaceDeployMinVersion then
          prev.pnpm_11
        else
          prev.pnpm_11.override {
            version = pnpmWorkspaceDeployMinVersion;
            hash = "sha256-V6l+byOj+v/AMVOk74x3CgVSYSuGQK6+Ob/dV1TQ69w=";
          };
    in
    assert prev.lib.assertMsg (prev.lib.versionAtLeast pnpm.version pnpmWorkspaceDeployMinVersion)
      "dsh: pnpmWorkspaceDeploy resolved to ${pnpm.version}, older than ${pnpmWorkspaceDeployMinVersion}";
    pnpm;
  # Keep pnpm from downloading a package manager version declared by an
  # upstream project. Upstream release lockfiles are the source of truth, so
  # their pinned dependencies must not be blocked by pnpm's release-age default.
  # The fetcher defaults to the deploy pnpm, so a bundle only supplies a hash
  # and cannot fetch with a pnpm that the deploy step would reject.
  wrapFetchPnpmDeps =
    base:
    let
      wrapped = prev.lib.makeOverridable (
        args:
        base (
          args
          // {
            pnpm = args.pnpm or pnpmWorkspaceDeploy;
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
    inherit pnpmWorkspaceDeploy pnpmWorkspaceDeployMinVersion;
  };
  dsh = final.lib.makeScope final.newScope (
    self:
    {
      # Only the dsh package set gets the release-age opt-out. Exporting the
      # wrapped fetcher at the nixpkgs top level would change every unrelated
      # pnpm package.
      inherit buildDshBundle fetchPnpmDeps;
      inherit pnpmWorkspaceDeploy;
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
