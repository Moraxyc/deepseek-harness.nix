{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.merge-check = pkgs.runCommand "merge-check" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
        node --test ${../../../../.github/scripts}/merge-check.test.js
        touch "$out"
      '';
    };
}
