{
  lib,
  buildDshBundle,
  dsh-kernel,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel;
  pname = "dsh-web-app";
  artifacts = [
    {
      source = "bundles/web-app";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
    {
      source = "frontends/web";
      target = "lib/node_modules/@deepseek-ai/dsh-web-frontend";
    }
  ];
  dshBundles = [
    "@deepseek-ai/dsh-web-app"
    "@deepseek-ai/dsh-web-frontend"
  ];
  meta = {
    description = "dsh web bundle over dsh-base";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
