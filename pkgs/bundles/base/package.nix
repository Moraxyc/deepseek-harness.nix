{
  lib,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle.fromInstallation {
  pname = "dsh-base";
  packageName = "@deepseek-ai/dsh-base";
  installation = dsh-runtime;
  meta = {
    description = "Foundation shared by all dsh profiles";
    descriptions.zh-CN = "所有 dsh profile 共用的基础层";
    descriptions.ja = "すべての dsh プロファイルで共有される基盤レイヤー";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
