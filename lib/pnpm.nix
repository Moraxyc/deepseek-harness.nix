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
    let
      pnpm =
        if lib.versionAtLeast pnpm_11.version pnpmWorkspaceDeployMinVersion then
          pnpm_11
        else
          pnpm_11.override {
            version = pnpmWorkspaceDeployMinVersion;
            hash = "sha256-V6l+byOj+v/AMVOk74x3CgVSYSuGQK6+Ob/dV1TQ69w=";
          };
    in
    assert lib.assertMsg (lib.versionAtLeast pnpm.version pnpmWorkspaceDeployMinVersion)
      "dsh: pnpmWorkspaceDeploy resolved to ${pnpm.version}, older than ${pnpmWorkspaceDeployMinVersion}";
    pnpm;
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
