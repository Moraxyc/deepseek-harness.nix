{ lib, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      source = lib.fileset.toSource {
        root = ../../../../pkgs/dsh-workspace;
        fileset = lib.fileset.unions [
          ../../../../pkgs/dsh-workspace/runtime-importer.mjs
          ../../../../pkgs/dsh-workspace/runtime-importer.test.mjs
        ];
      };
    in
    {
      checks.runtime-importer =
        pkgs.runCommand "runtime-importer" { nativeBuildInputs = [ pkgs.nodejs-slim ]; }
          ''
            node --test ${source}/runtime-importer.test.mjs
            touch "$out"
          '';
    };
}
