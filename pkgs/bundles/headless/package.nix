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
    description = "dsh bundle with the core Agent/Session runner";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
