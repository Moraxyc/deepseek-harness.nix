{
  bundles,
  dsh,
}:
dsh.override {
  defaultBundles = [ bundles.web-app ];
  defaultProfile = "nix-web-ui";
  meta = {
    description = "Web-first setup with extra UI themes and components";
    descriptions.zh-CN = "以网页界面为主，包含额外 UI 主题与组件";
  };
  profiles.web-ui.bundles = with bundles; [
    web-app
    web-ui
  ];
}
