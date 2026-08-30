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
in
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

  postPatch = ''
    substituteInPlace pnpm-lock.yaml \
      --replace-fail "file:../../.dsh-cohorts/" "file:.dsh-cohorts/"
    mkdir -p ".dsh-cohorts/${dsh-workspace.version}"
    cp -r ${dsh-workspace.cohort}/. ".dsh-cohorts/${dsh-workspace.version}/"
    yq -i '
      .packages |= with_entries(
        (select(.key | contains("@file:.dsh-cohorts/")) |
          .value.resolution |= del(.integrity)) // .
      )
    ' pnpm-lock.yaml
    printf '%s\n' \
      'manage-package-manager-versions=false' \
      'node-linker=hoisted' \
      >> .npmrc
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
    packageSourceOverrides."*@file:../../.dsh-cohorts/*" =
      { pkg, ... }:
      "${dsh-workspace.cohort}/${lib.last (lib.splitString "/" pkg.url)}";
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
