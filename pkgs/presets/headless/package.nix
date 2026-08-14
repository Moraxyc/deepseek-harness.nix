{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  defaultProfile = "nix-headless";
  profiles = {
    headless.bundles = [ bundles.headless ];
  };
}
