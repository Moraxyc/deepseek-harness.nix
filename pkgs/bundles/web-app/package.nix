{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
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
  passthru.requiresWeb = true;
  meta = {
    description = "Web interface for dsh";
    descriptions.zh-CN = "dsh 的网页界面";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
