{
  lib,
  fetchFromGitHub,
  importPnpmLock,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  jq,
  pnpmConfigHook,
  pnpm_11,
  yq-go,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-plugin-subscriptions";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "V1ki";
    repo = "dsh-plugin-subscriptions";
    tag = "v${finalAttrs.version}";
    hash = "sha256-axXpkswe5t6pH2WFhdouPbMG7+LxSNOZ8iy+NAD/JvA=";
  };

  # The release lockfile contains absolute links to the author's DSH checkout.
  # Replace only those development links; the pinned kernel supplies the same
  # peers for type checking and runtime composition.
  postPatch = ''
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
          or (.key | test("@deepseek-ai/(cordis|dsh-attachment|dsh-home-paths|dsh-llm|dsh-tools|schemastery)"))
        )
      )
    ' pnpm-lock.yaml

    # dsh 0.1.5 exposes localized command descriptions as lazy functions.
    substituteInPlace src/client/index.ts \
      --replace-fail \
        "description: t('commandFast')" \
        "description: () => t('commandFast')"
  '';

  pnpmDeps = importPnpmLock {
    inherit (finalAttrs) pname version;
    pnpm = pnpm_11;
    lockfileJson = ./pnpm-lock.json;
    fetcherVersion = 4;
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [
    jq
    pnpm_11
    yq-go
  ];
  disallowedReferences = [ pnpm_11 ];
  linkKernelNodeModules = dsh-kernel;

  preBuild = ''
    rm -rf node_modules/@deepseek-ai
    mkdir -p node_modules/@deepseek-ai
    cp -rL ${dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai/. node_modules/@deepseek-ai/
    for clientPackage in dsh-client-ui-commands dsh-client-ui-slots; do
      rm -rf "node_modules/@deepseek-ai/$clientPackage"
      cp -r "${dsh-workspace}/lib/dsh-workspace/client-packages/@deepseek-ai/$clientPackage" \
        "node_modules/@deepseek-ai/$clientPackage"
      chmod -R u+w "node_modules/@deepseek-ai/$clientPackage"
    done
    for clientPackage in \
      dsh-api-remotes \
      dsh-api-session-controller \
      dsh-client-connection \
      dsh-client-locale \
      dsh-client-store \
      dsh-client-ui-conversation \
      dsh-client-ui-input-trigger \
      dsh-client-ui-primitives \
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

    appDir="$out/lib/node_modules/${finalAttrs.pname}"
    mkdir -p "$appDir/node_modules"
    cp -r package.json cordis.patch.yml lib "$appDir/"
    cp -rL node_modules/undici "$appDir/node_modules/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = ./update.sh;

  meta = {
    description = "Use ChatGPT, Claude, Grok, and GitHub Copilot subscriptions as DSH providers with OAuth login and a web settings UI";
    descriptions.zh-CN = "将 ChatGPT、Claude、Grok 和 GitHub Copilot 订阅作为 DSH provider，并提供 OAuth 登录与 Web 设置界面";
    homepage = "https://github.com/V1ki/dsh-plugin-subscriptions";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
