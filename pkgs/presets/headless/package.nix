{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  profiles = {
    headless.bundles = [ bundles.official.headless ];
  };
}
