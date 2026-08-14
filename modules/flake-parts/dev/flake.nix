{
  description = "DeepSeek Harness Nix (Development)";

  inputs = {
    dev-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    dev-flake-compat.url = "github:NixOS/flake-compat";

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
