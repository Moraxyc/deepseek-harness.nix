{
  description = "DSH Nix development flake";

  inputs = {
    dev-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    dev-flake-compat.url = "github:NixOS/flake-compat";
    nixpkgs-2605.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-compat.url = "github:NixOS/flake-compat";

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "dev-nixpkgs";
        flake-compat.follows = "dev-flake-compat";
      };
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "dev-nixpkgs";
    };
  };

  outputs = { ... }: { };
}
