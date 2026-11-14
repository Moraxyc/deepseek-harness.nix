{
  lib,
  dshSources,
  importPnpmLock,
  buildDshBundle,
  copyTree,
  dshCohort,
  dsh-runtime,
  dsh-workspace,
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
  inherit (dshSources."bundles.notification") version src;

  patches = [ ./invariant-compat.patch ];

  # The upstream lockfile points at a developer's external DSH checkout. The
  # installation supplies those peers during the source build; keep only published
  # package dependencies in the pnpm install.
  postPatch = ''
    yq -o=json \
      '.devDependencies |= with_entries(select(.key | test("^@deepseek-ai/") | not))' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    # The pnpm install reads the source lockfile, so it needs the same peers.
    yq -i '
      .importers.".".devDependencies |= with_entries(
        select(.key | test("^@deepseek-ai/") | not)
      )
    ' pnpm-lock.yaml

  '';

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpm_11;
    lockfileJson = dshSources."bundles.notification".artifacts."pnpm-lock.json";
    workspaceJson = lib.importJSON dshSources."bundles.notification".artifacts."pnpm-workspace.json";
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
  installation = dsh-runtime;

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    ${copyTree.followLinks {
      src = "${dsh-workspace.runtime}/node_modules/@deepseek-ai";
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

  meta = {
    description = "Browser desktop notifications for completed DeepSeek Harness turns with outcome and keyword filters";
    descriptions.zh-CN = "通过浏览器桌面通知提醒 DeepSeek Harness 回合完成，并支持结果与关键词筛选";
    descriptions.ja = "DeepSeek Harness のターン完了をブラウザーのデスクトップ通知で知らせ、結果とキーワードによるフィルタリングに対応";
    homepage = "https://github.com/omdsh-dev/dsh-notification";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
