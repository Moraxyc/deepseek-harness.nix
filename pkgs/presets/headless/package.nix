{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  defaultBundles = [ bundles.headless ];
  inherit extraPlugins;
  defaultProfile = "nix-headless";
  profiles = {
    headless.bundles = [ bundles.headless ];
  };
}
