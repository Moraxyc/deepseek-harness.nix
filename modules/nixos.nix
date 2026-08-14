{
  imports = [ ./nixos-program.nix ];

  nixpkgs.overlays = [ (import ../overlays/default.nix) ];
}
