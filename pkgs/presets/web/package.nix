{
  bundles,
  dsh,
}:
dsh.override {
  pname = "dsh-web";
  defaultProfile = "nix-web";
  meta = {
    description = "Web-first setup without extra UI components";
    descriptions.zh-CN = "以网页界面为主，不包含额外 UI 组件";
    descriptions.ja = "追加の UI コンポーネントを含まない、Web インターフェース中心のセットアップ";
  };
  profiles = {
    web.bundles = [ bundles.web-app ];
  };
}
