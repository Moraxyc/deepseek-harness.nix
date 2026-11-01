{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-memento";
  version = "0.5.29";

  # The upstream package is authored JavaScript and has no compilation step.
  src = fetchFromGitHub {
    owner = "PerryLink";
    repo = "dsh-memento";
    tag = "v${finalAttrs.version}";
    hash = "sha256-cA7gffB//5DQj1aDeIwUPY6RXcxUBKppKX4FzluE7Js=";
  };

  npmDeps = null;
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-memento"
    mkdir -p "$appDir"
    cp -r index.mjs types.d.ts lib client cordis.patch.yml package.json "$appDir/"

    runHook postInstall
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Bounded, layered, approval-gated, auditable cross-session memory for DeepSeek Harness with a local SQLite provider";
    descriptions.zh-CN = "为 DeepSeek Harness 提供有界、分层、需审批且可审计的跨会话记忆与本地 SQLite 存储";
    descriptions.ja = "ローカル SQLite プロバイダーを備えた、範囲限定・階層型・承認制・監査可能な DeepSeek Harness 向けセッション間メモリ";
    homepage = "https://github.com/PerryLink/dsh-memento";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
