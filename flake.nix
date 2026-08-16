{
  description = "DeepSeek Harness Nix";

  nixConfig = {
    extra-substituters = [ "https://deepseek-harness-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="
    ];
  };

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
