{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  pnpmConfigHook,
  pnpm_11,
  yq-go,
  nix-update-script,
}:
let
  fetchPnpmDeps' = fetchPnpmDeps.override { yq = yq-go; };
in
buildDshBundle (finalAttrs: {
  pname = "dsh-notification";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-notification";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rs6hWEds6wlH3psDqNPdZLdzhpWcAAqBkrKwJ0hkNXo=";
  };

  # The upstream lockfile points at a developer's external DSH checkout. The
  # kernel supplies those peers during the source build; keep only published
  # package dependencies in the pnpm install.
  postPatch = ''
    yq -o=json \
      '.devDependencies |= with_entries(select(.key | test("^@deepseek-ai/") | not))' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    yq -i '
      .importers.".".devDependencies |= with_entries(
        select(.key | test("^@deepseek-ai/") | not)
      )
    ' pnpm-lock.yaml

  '';

  pnpmDeps = fetchPnpmDeps' {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    postPatch = finalAttrs.postPatch;
    hash = "sha256-pTHoDj3MwGC4snJ5J8eKW0slfMdcEhvgmLgD+Kqa8eM=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [
    pnpm_11
    yq-go
  ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    mkdir -p node_modules/@deepseek-ai
    cp -rL ${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai/. node_modules/@deepseek-ai/
    rm -rf node_modules/@deepseek-ai/dsh-client-ui-slots
    cp -r ${dsh-workspace}/lib/dsh-workspace/client-packages/@deepseek-ai/dsh-client-ui-slots \
      node_modules/@deepseek-ai/dsh-client-ui-slots
    chmod -R u+w node_modules/@deepseek-ai/dsh-client-ui-slots

    for clientPackage in \
      dsh-api-remotes \
      dsh-api-session-controller \
      dsh-client-connection \
      dsh-client-locale \
      dsh-client-store \
      dsh-client-ui-renderer \
      dsh-client-ui-session \
      dsh-client-ui-settings; do
      archive="${dsh-workspace.cohort}/deepseek-ai-$clientPackage-${dsh-workspace.version}.tgz"
      packageDir="node_modules/@deepseek-ai/$clientPackage"
      rm -rf "$packageDir"
      mkdir -p "$packageDir"
      tar -xzf "$archive" -C "$packageDir" --strip-components=1
      chmod -R u+w "$packageDir"
    done
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-notification"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml dsh.plugin.json README.md README.zh.md LICENSE lib "$appDir/"
    cp -rL node_modules/zod "$appDir/node_modules/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Browser desktop notifications for completed DeepSeek Harness turns with outcome and keyword filters";
    descriptions.zh-CN = "通过浏览器桌面通知提醒 DeepSeek Harness 回合完成，并支持结果与关键词筛选";
    homepage = "https://github.com/omdsh-dev/dsh-notification";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
