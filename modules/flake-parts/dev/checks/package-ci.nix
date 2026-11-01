{ lib, ... }:

{
  perSystem =
    { config, pkgs, ... }:
    let
      packageSet = config.legacyPackages.ciPackageAttrs;
      packageSetJson = pkgs.writeText "ci-package-attrs.json" (builtins.toJSON packageSet);
      fixtureNix = pkgs.writeShellScriptBin "nix" ''
        case "$*" in
          *builtins.currentSystem*) printf '%s\n' ${lib.escapeShellArg pkgs.stdenv.hostPlatform.system} ;;
          *ciPackageAttrs*) cat ${packageSetJson} ;;
          *) exit 1 ;;
        esac
      '';
      expectedAttrs = [
        packageSet.packages.dsh
        packageSet.packages.dsh-desktop
        packageSet.packages.dsh-desktop-official
        packageSet.packages.dsh-desktop-unofficial
      ]
      ++ lib.attrValues packageSet.presets
      ++ lib.attrValues packageSet.bundleCompositions;
      expected = pkgs.writeText "dsh-dependent-attrs" (
        lib.concatStringsSep "\n" (lib.sort builtins.lessThan (lib.unique expectedAttrs)) + "\n"
      );
    in
    {
      checks.package-ci-selection =
        pkgs.runCommand "package-ci-selection"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.gitMinimal
              pkgs.jq
              fixtureNix
            ];
          }
          ''
            git -c init.defaultBranch=main init
            git config user.name "CI selection check"
            git config user.email "ci@example.invalid"
            git commit --allow-empty -m base
            base=$(git rev-parse HEAD)

            mkdir -p pkgs/dsh
            printf '{}\n' > pkgs/dsh/package.nix
            git add pkgs/dsh/package.nix
            git commit -m "Change dsh"

            bash ${../../../../scripts/select-package-ci-attrs.sh} "$base" > selected
            cmp ${expected} selected
            touch "$out"
          '';
    };
}
