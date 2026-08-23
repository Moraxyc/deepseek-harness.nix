{
  buildDshBundle,
  codex,
  dsh-kernel,
  dsh-workspace,
  lib,
  stdenvNoCC,
}:
let
  platformKey = with stdenvNoCC.hostPlatform.node; "${platform}-${arch}";
in
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-subagent-codex";
  artifacts = [
    {
      source = "providers/subagent-codex";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
    }
  ];
  linkKernelNodeModules = dsh-kernel;
  runtimeDeps = [ codex ];
  postInstall = ''
    providerRoot="$out/lib/node_modules/@deepseek-ai/${finalAttrs.pname}"
    [ -d "$providerRoot/node_modules/@openai/codex" ] || {
      printf 'dsh-subagent-codex: bundled @openai/codex payload is missing\n' >&2
      exit 1
    }
    [ -d "$providerRoot/node_modules/@openai/codex-${platformKey}" ] || {
      printf 'dsh-subagent-codex: bundled platform Codex payload is missing: @openai/codex-${platformKey}\n' >&2
      exit 1
    }
  '';
  meta = {
    description = "Optional Codex subagent provider for dsh";
    descriptions.zh-CN = "dsh 的可选 Codex 子 agent 提供方";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
