{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  defaultProfile = "nix-web";
  profiles = {
    web.bundles = [ bundles.official.web-app ];
  };
}
