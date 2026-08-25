{
  lib,
  bubblewrap,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  ripgrep,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-base";
  packageName = "@deepseek-ai/dsh-base";
  linkKernelNodeModules = dsh-kernel;
  runtimeDeps = [ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ bubblewrap ];
  meta = {
    description = "Foundation shared by all dsh profiles";
    descriptions.zh-CN = "所有 dsh profile 共用的基础层";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
