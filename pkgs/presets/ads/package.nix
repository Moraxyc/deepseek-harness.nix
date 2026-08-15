{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  defaultBundles = [ bundles.web-app ];
  inherit extraPlugins;
  defaultProfile = "nix-ads";
  meta = {
    description = "DSH setup with local portal ads and scam-ad parodies";
    descriptions.zh-CN = "带本地门户广告与诈骗广告仿制内容的 DSH 组合";
  };
  profiles = {
    ads.bundles = with bundles; [
      web-app
      ads
    ];
  };
}
