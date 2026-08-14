{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          jq
          nix-update
          nixfmt-rfc-style
          yq-go
        ];
      };

      formatter = pkgs.nixfmt-rfc-style;
    };
}
