{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  defaultProfile = "nix-tui";
  meta = {
    description = "Terminal-focused setup with an interactive interface";
    descriptions.zh-CN = "以交互式终端界面为主的组合";
  };
  profiles = {
    tui.bundles = [ bundles.tui ];
  };
}
