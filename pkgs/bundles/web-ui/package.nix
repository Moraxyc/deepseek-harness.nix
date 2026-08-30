{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  importPnpmLock,
  pnpmConfigHook,
  pnpm_11,
  yq-go,
}:
let
  fetchPnpmDeps' = fetchPnpmDeps.override { yq = yq-go; };
  lockfile = lib.importJSON ./pnpm-lock.json;
  cohortVersions = lib.unique (
    lib.mapAttrsToList (_: package: package.version) (
      lib.filterAttrs (
        _: package: lib.hasInfix ".dsh-cohorts/" (package.resolution.tarball or "")
      ) lockfile.packages
    )
  );
  cohortArchiveName =
    packageName:
    "${lib.replaceStrings [ "@" "/" ] [ "" "-" ] packageName}-${dsh-workspace.version}.tgz";
in
assert lib.assertMsg (cohortVersions == [ dsh-workspace.version ]) ''
  dsh-web-ui: lockfile cohort versions ${builtins.toJSON cohortVersions} do not match dsh-workspace ${dsh-workspace.version}
'';
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-web-ui";
  version = "0.3.8";
  deployPackage = "@linxin666/dsh-web-all";
  stripPrepareScripts = true;
  disableChildBundlePatches = true;
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "zhu1090093659";
    repo = "dsh-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Iip2UQJq7vUd5vT1UP4djf4nAT45XUq/5gQdm/3n8Hw=";
  };

  patches = [ ./alpha2-compat.patch ];

  postPatch = ''
    DSH_WEB_UI_LOCK=${./pnpm-lock.json} \
      yq -i '.overrides = load(strenv(DSH_WEB_UI_LOCK)).overrides' pnpm-workspace.yaml
    yq -o=yaml '.' ${./pnpm-lock.json} > pnpm-lock.yaml
    mkdir -p ".dsh-cohorts/${dsh-workspace.version}"
    cp -r ${dsh-workspace.cohort}/. ".dsh-cohorts/${dsh-workspace.version}/"
    printf '%s\n' \
      'manage-package-manager-versions=false' \
      'node-linker=hoisted' \
      >> .npmrc
  '';

  preDeploy = ''
    # pnpm deploy resolves file: tarballs from the clean destination. Point
    # those generated lockfile entries at the immutable cohort input instead
    # of pre-populating the destination (which deploy rejects as non-empty).
    substituteInPlace pnpm-lock.yaml \
      --replace-fail \
      "file:.dsh-cohorts/${dsh-workspace.version}/" \
      "file:${dsh-workspace.cohort}/"
  '';

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    fetchPnpmDeps = fetchPnpmDeps';
    lockfileJson = ./pnpm-lock.json;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    patchedDependencySources = {
      "@morlay/ui-conversation-message-actions@0.0.11" =
        "${finalAttrs.src}/patches/@morlay__ui-conversation-message-actions@0.0.11.patch";
    };
    packageSourceOverrides."*@file:*.dsh-cohorts/*" =
      { pkg, ... }:
      "${dsh-workspace.cohort}/${cohortArchiveName pkg.name}";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ yq-go ];

  preBuild = ''
    for d in packages/*/node_modules; do
      [ -d "$d" ] || continue
      patchShebangs "$d"
    done
  '';

  postDeploy = ''
    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    mv \
      "$out/lib/package.json" \
      "$out/lib/cordis.patch.yml" \
      "$out/lib/lib" \
      "$deployPackagePath/"

    # Prune
    find "$out/lib/node_modules" -type f -path '*/build/*' ! -name '*.node' -delete
    find "$out/lib/node_modules" -depth -type d -empty -delete
  '';

  passthru = {
    updateScript = ./update.sh;
    requiresWeb = true;
  };

  meta = {
    description = "Extra web UI themes and components";
    descriptions.zh-CN = "额外的 Web UI 主题与组件";
    homepage = "https://github.com/zhu1090093659/dsh-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
