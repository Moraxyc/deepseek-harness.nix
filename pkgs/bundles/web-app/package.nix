{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  imagemagick,
  jq,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-web-app";
  packageName = "@deepseek-ai/dsh-web-app";
  linkKernelNodeModules = dsh-kernel;
  artifacts = [
    {
      source = "frontends/web";
      target = "lib/node_modules/@deepseek-ai/dsh-web-frontend";
    }
  ];

  postInstall = import ../../../lib/web-maskable-icons.nix {
    inherit lib imagemagick jq;
  } "$out/lib/node_modules/@deepseek-ai/dsh-web-frontend";

  passthru.requiresWeb = true;
  meta = {
    description = "Web interface for dsh";
    descriptions.zh-CN = "dsh 的网页界面";
    descriptions.ja = "dsh の Web インターフェース";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
