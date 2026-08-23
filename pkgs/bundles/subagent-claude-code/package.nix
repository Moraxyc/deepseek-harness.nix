{
  buildDshBundle,
  claude-code,
  dsh-kernel,
  dsh-workspace,
  lib,
  stdenvNoCC,
}:
let
  platformKey = with stdenvNoCC.hostPlatform.node; "${platform}-${arch}";
  claudePlatformKey =
    if stdenvNoCC.hostPlatform.isLinux && stdenvNoCC.hostPlatform.libc == "musl" then
      "${platformKey}-musl"
    else
      platformKey;
in
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-subagent-claude-code";
  artifacts = [
    {
      source = "providers/subagent-claude-code";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
    }
  ];
  linkKernelNodeModules = dsh-kernel;
  runtimeDeps = [ claude-code ];
  postInstall = ''
    providerRoot="$out/lib/node_modules/@deepseek-ai/${finalAttrs.pname}"
    claudeBinary="$providerRoot/node_modules/@anthropic-ai/claude-agent-sdk-${claudePlatformKey}/claude"
    [ -x "$claudeBinary" ] || {
      printf 'dsh-subagent-claude-code: Claude Agent SDK platform payload is missing\n' >&2
      exit 1
    }
    find "$providerRoot" -type d -exec chmod u+rwx {} +
    rm -f "$claudeBinary"
    ln -s ${lib.getExe claude-code} "$claudeBinary"
  '';
  meta = {
    description = "Optional Claude Code subagent provider for dsh";
    descriptions.zh-CN = "dsh 的可选 Claude Code 子 agent 提供方";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = claude-code.meta.platforms;
  };
})
