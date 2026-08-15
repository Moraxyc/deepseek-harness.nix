{
  bundles,
  dsh,
}:
dsh.override {
  defaultBundles = [ bundles.web-app ];
  defaultProfile = "nix-web";
  meta = {
    description = "Web-first setup without extra UI components";
    descriptions.zh-CN = "以网页界面为主，不包含额外 UI 组件";
  };
  profiles = {
    web.bundles = [ bundles.web-app ];
  };
}
