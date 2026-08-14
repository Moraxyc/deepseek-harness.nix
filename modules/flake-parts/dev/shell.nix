{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        inherit (config.pre-commit.settings) shellHook;
        nativeBuildInputs = config.pre-commit.settings.enabledPackages;
        packages = with pkgs; [
          jq
          nix-update
          nixfmt-rfc-style
          yq-go
        ];
      };
    };
}
