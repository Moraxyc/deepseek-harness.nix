{
  lib,
  fetchPnpmDeps,
  pnpm_11,
}:
let
  # Workspace injection requires pnpm >= 11.22.0 (pnpm/pnpm#13754).
  # Older versions leave source-workspace links in deployed bundles.
  pnpmWorkspaceDeployMinVersion = "11.22.0";
  pnpmWorkspaceDeploy =
    assert lib.assertMsg (lib.versionAtLeast pnpm_11.version pnpmWorkspaceDeployMinVersion)
      "dsh: pnpm_11 resolved to ${pnpm_11.version}, older than ${pnpmWorkspaceDeployMinVersion}";
    pnpm_11;
  # Upstream release lockfiles must bypass pnpm's release-age policy and
  # package-manager downloads.
  wrapFetchPnpmDeps =
    base:
    let
      wrapped = lib.makeOverridable (
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
in
{
  inherit pnpmWorkspaceDeploy pnpmWorkspaceDeployMinVersion;
  fetchPnpmDeps = wrapFetchPnpmDeps fetchPnpmDeps;
}
