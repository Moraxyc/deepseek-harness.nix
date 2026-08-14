{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  profiles = {
    web.bundles = [ bundles.official.web-app ];
  };
}
