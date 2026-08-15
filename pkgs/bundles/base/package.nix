{
  lib,
  bubblewrap,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  ripgrep,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-base";
  artifacts = [
    {
      source = "bundles/base";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
  ];
  runtimeDeps = [ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ bubblewrap ];
  meta = {
    description = "Foundation shared by all dsh profiles";
    descriptions.zh-CN = "所有 dsh profile 共用的基础层";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
