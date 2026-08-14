{
  lib,
  buildDshBundle,
  dsh-kernel,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel;
  pname = "dsh-headless";
  artifacts = [
    {
      source = "bundles/headless";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
  ];
  dshBundles = [ "@deepseek-ai/dsh-headless" ];
  meta = {
    description = "dsh bundle with the core Agent/Session runner";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
