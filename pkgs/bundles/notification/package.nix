{
  lib,
  fetchFromGitHub,
  importPnpmLock,
  buildDshBundle,
  copyTree,
  dshCohort,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  yq-go,
}:
let
  clientPackages = dshCohort.select [
    "dsh-client-ui-slots"
    "dsh-api-remotes"
    "dsh-api-session-controller"
    "dsh-client-connection"
    "dsh-client-locale"
    "dsh-client-store"
    "dsh-client-ui-renderer"
    "dsh-client-ui-session"
    "dsh-client-ui-settings"
  ];
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

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpm_11;
    lockfileJson = ./pnpm-lock.json;
    workspaceJson = lib.importJSON ./pnpm-workspace.json;
    fetcherVersion = 4;
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
    ${copyTree.followLinks {
      src = "${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai";
      dest = "node_modules/@deepseek-ai";
    }}
    ${dshCohort.installPackages { names = clientPackages; }}
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-notification"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml dsh.plugin.json README.md README.zh.md LICENSE lib "$appDir/"
    ${copyTree.followLinks {
      src = "node_modules/zod";
      dest = "$appDir/node_modules/zod";
    }}

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = ./update.sh;

  meta = {
    description = "Browser desktop notifications for completed DeepSeek Harness turns with outcome and keyword filters";
    descriptions.zh-CN = "通过浏览器桌面通知提醒 DeepSeek Harness 回合完成，并支持结果与关键词筛选";
    homepage = "https://github.com/omdsh-dev/dsh-notification";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
