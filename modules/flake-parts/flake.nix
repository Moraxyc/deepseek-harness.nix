{
  inputs,
  ...
}:
{
  flake = {
    overlays.default = import ../../overlays/default.nix {
      inherit (inputs) dsh-src;
    };
    nixosModules.default = import ../../modules/nixos.nix {
      inherit (inputs) dsh-src;
    };
    lib = import ../../lib { inherit inputs; };
  };
}
