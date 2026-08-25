{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-headless";
  packageName = "@deepseek-ai/dsh-headless";
  linkKernelNodeModules = dsh-kernel;
  meta = {
    description = "Run dsh without a graphical interface";
    descriptions.zh-CN = "无需图形界面即可运行 dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
