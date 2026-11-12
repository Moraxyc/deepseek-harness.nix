{
  lib,
  fetchFromGitHub,
  importPnpmLock,
  buildDshBundle,
  copyTree,
  dshCohort,
  dsh-runtime,
  dsh-workspace,
  jq,
  pnpmConfigHook,
  pnpm_11,
  yq-go,
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
  version = "0.9.13";

  src = fetchFromGitHub {
    owner = "V1ki";
    repo = "dsh-plugin-subscriptions";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5EaGJryDD0AsBsJ7PLgizhtdX9nLWf+y2R34WQ1TsJg=";
  };

  # rc.2 restricts error constructors and removes the public anchor hook.
  patches = [ ./rc2-runtime-contracts.patch ];

  # The release lockfile contains absolute links to the author's DSH checkout.
  # Replace only those development links; the pinned installation supplies the same
  # peers for type checking and runtime composition.
  postPatch = ''
    yq -o=yaml '.' ${./pnpm-workspace.json} > pnpm-workspace.yaml

    jq '
      . as $root
      | if .devDependencies then
          .devDependencies |= with_entries(select(
            (.key | startswith("@deepseek-ai/") | not)
            or ($root.peerDependencies[.key] != null)
          ))
        else .
        end
    ' package.json > package.json.tmp
    mv package.json.tmp package.json

    yq -i '
      .importers.".".devDependencies |= with_entries(
        select(
          (.key | test("^@deepseek-ai/") | not)
          or (.key | test("@deepseek-ai/(cordis|dsh-attachment|dsh-home-paths|dsh-llm|dsh-tools|dsh-web|schemastery)"))
        )
      )
    ' pnpm-lock.yaml

    # dsh 0.1.6 types agent/created listeners as returning undefined, while
    # this release's inferred callback return is void.
    substituteInPlace src/index.ts \
      --replace-fail \
      'if (deny.length) agent.ctx.tools.restrict({ deny })' \
      'if (deny.length) agent.ctx.tools.restrict({ deny }); return undefined'

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
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm exec tsc -p tsconfig.test.json
    node --test lib-test/test/pool.spec.js lib-test/test/antigravity-images.spec.js \
      lib-test/test/rate-limit.spec.js lib-test/test/pool-health.spec.js \
      lib-test/test/models.spec.js lib-test/test/subagent-speed.spec.js
    runHook postCheck
  '';
  nativeBuildInputs = [
    jq
    pnpm_11
    yq-go
  ];
  disallowedReferences = [ pnpm_11 ];
  # The compatibility patch uses the rc.2 host error factory.
  dshEngines = "0.2.2-rc.2";
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
  passthru.updateScript = ./update.sh;

  meta = {
    description = "Use ChatGPT, Claude, Grok, and GitHub Copilot subscriptions as DSH providers with OAuth login and a web settings UI";
    descriptions.zh-CN = "将 ChatGPT、Claude、Grok 和 GitHub Copilot 订阅作为 DSH provider，并提供 OAuth 登录与 Web 设置界面";
    descriptions.ja = "ChatGPT、Claude、Grok、GitHub Copilot のサブスクリプションを DSH プロバイダーとして利用し、OAuth ログインと Web 設定 UI を提供";
    homepage = "https://github.com/V1ki/dsh-plugin-subscriptions";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
