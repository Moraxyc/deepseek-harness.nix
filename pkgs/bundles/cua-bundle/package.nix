{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-cua-native,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-cua-bundle";
  packageName = "@deepseek-ai/dsh-cua-bundle";
  linkKernelNodeModules = dsh-kernel;
  stripExclude = [ "*/DSH Computer Use.app/*" ];
  passthru.requiresWeb = true;

  meta = {
    description = "macOS Computer Use with native permission setup";
    descriptions.zh-CN = "macOS Computer Use 与原生权限设置";
    descriptions.ja = "macOS Computer Use とネイティブ権限設定";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = dsh-cua-native.meta.platforms;
  };
})
