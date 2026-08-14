{
  bundles,
  dsh,
  extraPlugins ? [ ],
}:
dsh.override {
  inherit extraPlugins;
  defaultProfile = "nix-tui";
  profiles = {
    tui.bundles = [ bundles.optional.tui ];
  };
}
