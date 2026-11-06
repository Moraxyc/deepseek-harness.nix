{
  lib,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle.fromInstallation {
  pname = "dsh-web-app";
  packageName = "@deepseek-ai/dsh-web-app";
  installation = dsh-runtime;
  passthru.requiresWeb = true;
  meta = {
    description = "Web interface for dsh";
    descriptions.zh-CN = "dsh 的网页界面";
    descriptions.ja = "dsh の Web インターフェース";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
