{ inputs, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        inherit (config.pre-commit.settings) shellHook;
        nativeBuildInputs = config.pre-commit.settings.enabledPackages;
        packages = with pkgs; [
          jq
          gitMinimal
          (pkgs.callPackage (inputs.fetchrix + "/nix/package.nix") { })
          yarn-berry_4.yarn-berry-fetcher
          nixfmt
          pre-commit
          yq-go
        ];
      };
    };
}
