{
  lib,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle.fromInstallation {
  pname = "dsh-headless";
  packageName = "@deepseek-ai/dsh-headless";
  installation = dsh-runtime;
  meta = {
    description = "Run dsh without a graphical interface";
    descriptions.zh-CN = "无需图形界面即可运行 dsh";
    descriptions.ja = "グラフィカルインターフェースなしで dsh を実行";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
