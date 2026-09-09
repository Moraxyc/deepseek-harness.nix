{
  inputs,
  ...
}:
{
  flake = {
    overlays.default = import ../../overlays/default.nix;
    nixosModules.default = import ../../modules/nixos.nix;
    homeModules.default = import ../../modules/home-manager.nix;
  };
}
