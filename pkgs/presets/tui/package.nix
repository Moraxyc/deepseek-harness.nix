{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  profiles = {
    tui.bundles = [ bundles.optional.tui ];
  };
}
