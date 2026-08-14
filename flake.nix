{
  description = "DeepSeek Harness Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/triplet";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.flake-parts.flakeModules.partitions
        ./modules/flake-parts/flake.nix
        ./modules/flake-parts/nixpkgs.nix
        ./modules/flake-parts/packages.nix
      ];

      partitions.dev = {
        module = ./modules/flake-parts/dev/flake-module.nix;
        extraInputsFlake = ./modules/flake-parts/dev;
      };

      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
      };
    };
}
