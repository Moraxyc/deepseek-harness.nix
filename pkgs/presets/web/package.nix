{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  defaultBundles = [ bundles.web-app ];
  inherit extraPlugins;
  defaultProfile = "nix-web";
  profiles = {
    web.bundles = [ bundles.web-app ];
  };
}
