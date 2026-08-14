{
  description = "DeepSeek Harness Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    dsh-src = {
      url = "github:deepseek-ai/deepseek-harness";
      flake = false;
    };
    systems.url = "github:nix-systems/triplet";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        ./modules/flake-parts/flake.nix
        ./modules/flake-parts/nixpkgs.nix
        ./modules/flake-parts/packages.nix
        ./modules/flake-parts/shell.nix
      ];
    };
}
