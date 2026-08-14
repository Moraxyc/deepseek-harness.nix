{ dsh-src }:
{
  imports = [ ./nixos-program.nix ];

  nixpkgs.overlays = [ (import ../overlays/default.nix { inherit dsh-src; }) ];
}
