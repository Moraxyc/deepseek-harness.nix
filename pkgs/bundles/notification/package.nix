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
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "dsh-notification";
    tag = "v${finalAttrs.version}";
    hash = "sha256-v3927JxC2JPIekk5gyrQV049ajMIGXlV4Ycwg/GK5HM=";
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

    sed -i '/^    schema: z\.object({$/,/^    stateVersion: 1,$/c\
    stateSchema: z.object({\
      openTurn: z.object({\
        turn: z.number().int().nonnegative(),\
        text: z.string(),\
        tools: z.array(z.string()),\
      }).nullable(),\
      last: z.object({\
        turn: z.number().int().nonnegative(),\
        reason: z.string(),\
        body: z.string(),\
        tools: z.array(z.string()),\
      }).nullable(),\
    }).strict(),\
    wire: {\
      viewSchema: z.object({\
        turn: z.number().int().nonnegative(),\
        reason: z.string(),\
        body: z.string(),\
        tools: z.array(z.string()),\
      }).strict(),\
      view: state => state.last ?? EMPTY_PROJECTION,\
    },\
    init: () => ({ openTurn: null, last: null }),\
    apply: (state, event) => applyProjectionEvent(state, event, config.maxBodyChars),\
    stateVersion: 1,' src/projection.ts
    substituteInPlace src/projection.ts \
      --replace-fail \
        "export function notificationProjection(config: ResolvedConfig): ProjectionDefinition<'notification', NotificationProjectionState> {" \
        "export function notificationProjection(config: ResolvedConfig): Omit<ProjectionDefinition<'notification', NotificationProjectionState>, 'wire'> & { wire: NonNullable<ProjectionDefinition<'notification', NotificationProjectionState>['wire']> } {"

    sed -i '$i\
      interface SessionProjectionStateMap {\
        notification: import("./projection.ts").NotificationProjectionState\
      }' src/contract.ts
    substituteInPlace src/client/index.ts \
      --replace-fail \
        "const observedTurn = new Map<string, number>()" \
        "const observedTurn = new Map<SessionId, number>()"
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
