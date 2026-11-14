{ lib }:
let
  lock = lib.importJSON ../modules/flake-parts/dev/flake.lock;
  pin = lock.nodes.${lock.nodes.root.inputs.fetchrix}.locked;
  src = builtins.fetchTarball {
    url = "https://github.com/${pin.owner}/${pin.repo}/archive/${pin.rev}.tar.gz";
    sha256 = pin.narHash;
  };
in
import (src + "/nix/lib.nix") { inherit lib; }
