{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  defaultBundles = [ bundles.headless ];
  inherit extraPlugins;
  defaultProfile = "nix-headless";
  meta = {
    description = "Simple setup for running dsh from the terminal";
    descriptions.zh-CN = "适合从终端运行 dsh 的简洁组合";
  };
  profiles = {
    headless.bundles = [ bundles.headless ];
  };
}
