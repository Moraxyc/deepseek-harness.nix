{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-headless";
  artifacts = [
    {
      source = "bundles/headless";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
  ];
  meta = {
    description = "Run dsh without a graphical interface";
    descriptions.zh-CN = "无需图形界面即可运行 dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
