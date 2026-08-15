{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  defaultBundles = [ bundles.web-app ];
  inherit extraPlugins;
  defaultProfile = "nix-web-ui";
  profiles.web-ui.bundles = with bundles; [
    web-app
    web-ui
  ];
}
