{
  bundles,
  dsh,
}:
dsh.override {
  defaultBundles = [ bundles.headless ];
  defaultProfile = "nix-tui";
  meta = {
    description = "Terminal-focused setup with an interactive interface";
    descriptions.zh-CN = "以交互式终端界面为主的组合";
  };
  profiles = {
    tui.bundles = [ bundles.tui ];
  };
}
