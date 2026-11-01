{
  bundles,
  dsh,
}:
dsh.override {
  pname = "dsh-headless";
  defaultBundles = [ bundles.headless ];
  defaultProfile = "nix-headless";
  meta = {
    description = "Simple setup for running dsh from the terminal";
    descriptions.zh-CN = "适合从终端运行 dsh 的简洁组合";
    descriptions.ja = "ターミナルから dsh を実行するためのシンプルなセットアップ";
  };
  profiles = {
    headless.bundles = [ bundles.headless ];
  };
}
