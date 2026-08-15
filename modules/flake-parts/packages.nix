{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      dsh = pkgs.dsh;
    in
    {
      packages = {
        default = dsh.dsh;
        inherit (dsh)
          dsh-desktop
          dsh-kernel
          dsh-workspace
          ;
        inherit (dsh)
          dsh
          ;
      };

      legacyPackages = {
        inherit (dsh) bundles presets;
      };

      apps.default = {
        type = "app";
        program = "${dsh.dsh}/bin/dsh";
      };

      apps.dsh-desktop = {
        type = "app";
        program = "${dsh.dsh-desktop}/bin/dsh-desktop";
      };

      apps.generate-docs = {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            name = "generate-docs";
            runtimeInputs = with pkgs; [
              coreutils
              diffutils
              git
              jq
              nix
              prettier
            ];
            text = builtins.readFile ../../scripts/generate-docs.sh;
          }
        }/bin/generate-docs";
      };
    };
}
