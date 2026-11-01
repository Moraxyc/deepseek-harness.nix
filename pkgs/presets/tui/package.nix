{
  bundles,
  dsh,
}:
dsh.override {
  pname = "dsh-tui";
  defaultBundles = [ bundles.headless ];
  defaultProfile = "nix-tui";
  meta = {
    description = "Terminal-focused setup with an interactive interface";
    descriptions.zh-CN = "以交互式终端界面为主的组合";
    descriptions.ja = "対話型インターフェースを備えた、ターミナル中心のセットアップ";
  };
  profiles = {
    tui = {
      requiresTui = true;
    };
  };
}
