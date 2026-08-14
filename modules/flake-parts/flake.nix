{
  inputs,
  ...
}:
{
  flake = {
    overlays.default = import ../../overlays/default.nix;
    nixosModules.default = import ../../modules/nixos.nix;
    lib = import ../../lib { inherit inputs; };
  };
}
