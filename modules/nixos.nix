{
  imports = [
    ./nixos-program.nix
    ./nixos-service.nix
  ];

  nixpkgs.overlays = [ (import ../overlays/default.nix) ];
}
