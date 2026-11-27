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
}:
let
  clientPackages = dshCohort.select [
    "dsh-client-ui-commands"
    "dsh-client-ui-slots"
    "dsh-api-remotes"
    "dsh-api-session-controller"
    "dsh-client-connection"
    "dsh-client-locale"
    "dsh-client-store"
    "dsh-client-ui-conversation"
    "dsh-client-ui-input-trigger"
    "dsh-client-ui-primitives"
    "dsh-client-ui-renderer"
    "dsh-client-ui-session"
    "dsh-client-ui-settings"
  ];
in
buildDshBundle (finalAttrs: {
  pname = "dsh-plugin-subscriptions";
  inherit (dshSources."bundles.subscriptions") version src;

  # dsh-attachment 0.2.3-alpha.2 requires maxImageBytes and imageTargetBytes on ImageRequestTarget.
  patches = [ ./alpha2-image-request-target.patch ];

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpm_11;
    lockfileJson = dshSources."bundles.subscriptions".artifacts."pnpm-lock.json";
    workspaceJson = lib.importJSON dshSources."bundles.subscriptions".artifacts."pnpm-workspace.json";
    fetcherVersion = 4;
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm exec tsc -p tsconfig.test.json
    node --test lib-test/test/pool.spec.js lib-test/test/antigravity-images.spec.js \
      lib-test/test/rate-limit.spec.js lib-test/test/pool-health.spec.js \
      lib-test/test/models.spec.js lib-test/test/subagent-speed.spec.js
    runHook postCheck
  '';
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];
  installation = dsh-runtime;

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    mkdir -p node_modules/@deepseek-ai
    ln -s ${dsh-workspace.runtime}/node_modules/@deepseek-ai/* node_modules/@deepseek-ai/
    ${dshCohort.installPackages { names = clientPackages; }}
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/${finalAttrs.pname}"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml lib "$appDir/"
    ${copyTree.followLinks {
      src = "node_modules/undici";
      dest = "$appDir/node_modules/undici";
    }}

    runHook postInstall
  '';

  passthru.requiresWeb = true;

  meta = {
    description = "Use ChatGPT, Claude, Grok, and GitHub Copilot subscriptions as DSH providers with OAuth login and a web settings UI";
    descriptions.zh-CN = "将 ChatGPT、Claude、Grok 和 GitHub Copilot 订阅作为 DSH provider，并提供 OAuth 登录与 Web 设置界面";
    descriptions.ja = "ChatGPT、Claude、Grok、GitHub Copilot のサブスクリプションを DSH プロバイダーとして利用し、OAuth ログインと Web 設定 UI を提供";
    homepage = "https://github.com/V1ki/dsh-plugin-subscriptions";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
