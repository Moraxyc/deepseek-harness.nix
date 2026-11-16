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
      expectedBundle = pkgs.writeText "dsh-bundle-attrs" (
        lib.concatStringsSep "\n" (
          lib.sort builtins.lessThan (
            lib.unique (
              [
                packageSet.bundles.tui
                packageSet.bundleCompositions.tui
              ]
              ++ packageSet.bundleDependents.tui
            )
          )
        )
        + "\n"
      );
      expectedUnofficialDesktop = pkgs.writeText "dsh-unofficial-desktop-attrs" (
        packageSet.packages.dsh-desktop-unofficial + "\n"
      );
      allAttrsList =
        lib.attrValues packageSet.packages
        ++ lib.attrValues packageSet.bundles
        ++ lib.attrValues packageSet.presets
        ++ lib.attrValues packageSet.bundleCompositions;
      expectedAll = pkgs.writeText "all-package-attrs" (
        lib.concatStringsSep "\n" (lib.sort builtins.lessThan allAttrsList) + "\n"
      );
    in
    {
      checks.dsh-engines-update =
        pkgs.runCommand "dsh-engines-update"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.ast-grep
            ];
          }
          ''
            node --test ${../../../../scripts}/update-dsh-engines.test.mjs
            touch "$out"
          '';

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

            # A fetchrix pin change selects the bundle it belongs to.
            git reset --hard "$base" >/dev/null
            mkdir -p _sources/bundles.tui
            printf '{\n  "schema": 1,\n  "packages": {}\n}\n' > _sources/bundles.tui/pnpm-lock.json
            git add _sources/bundles.tui/pnpm-lock.json
            git commit -m "Update the tui pin"

            bash ${../../../../scripts/select-package-ci-attrs.sh} "$base" > selected-bundle
            cmp ${expectedBundle} selected-bundle

            # A lock.json update only selects the changed package entry.
            git reset --hard "$base" >/dev/null
            mkdir -p _sources
            cat > _sources/lock.json <<'JSON'
            {
              "schema": 1,
              "packages": {
                "bundles.tui": { "version": "0.1.0" },
                "dsh-desktop-unofficial": { "version": "1.0.0" },
                "dsh-workspace": { "version": "0.2.0" }
              }
            }
            JSON
            printf '[packages."bundles.tui"]\n' > fetchrix.toml
            git add _sources/lock.json fetchrix.toml
            git commit -m "Seed lockfile"
            lock_base=$(git rev-parse HEAD)

            cat > _sources/lock.json <<'JSON'
            {
              "schema": 1,
              "packages": {
                "bundles.tui": { "version": "0.2.0" },
                "dsh-desktop-unofficial": { "version": "1.0.0" },
                "dsh-workspace": { "version": "0.2.0" }
              }
            }
            JSON
            printf '[packages."bundles.tui"]\npname = "dsh-tui"\n' > fetchrix.toml
            git add _sources/lock.json fetchrix.toml
            git commit -m "Update tui in lock.json"

            bash ${../../../../scripts/select-package-ci-attrs.sh} "$lock_base" > selected-lock-bundle
            cmp ${expectedBundle} selected-lock-bundle

            git reset --hard "$lock_base" >/dev/null
            cat > _sources/lock.json <<'JSON'
            {
              "schema": 1,
              "packages": {
                "bundles.tui": { "version": "0.1.0" },
                "dsh-desktop-unofficial": { "version": "1.1.0" },
                "dsh-workspace": { "version": "0.2.0" }
              }
            }
            JSON
            git add _sources/lock.json
            git commit -m "Update unofficial desktop in lock.json"

            bash ${../../../../scripts/select-package-ci-attrs.sh} "$lock_base" > selected-lock-desktop
            cmp ${expectedUnofficialDesktop} selected-lock-desktop

            git reset --hard "$lock_base" >/dev/null
            cat > _sources/lock.json <<'JSON'
            {
              "schema": 1,
              "packages": {
                "bundles.tui": { "version": "0.1.0" },
                "dsh-desktop-unofficial": { "version": "1.0.0" },
                "dsh-workspace": { "version": "0.3.0" }
              }
            }
            JSON
            git add _sources/lock.json
            git commit -m "Update workspace in lock.json"

            bash ${../../../../scripts/select-package-ci-attrs.sh} "$lock_base" | sort -u > selected-lock-workspace
            cmp ${expectedAll} selected-lock-workspace

            git reset --hard "$lock_base" >/dev/null
            cat > _sources/lock.json <<'JSON'
            {
              "schema": 2,
              "packages": {
                "bundles.tui": { "version": "0.1.0" },
                "dsh-desktop-unofficial": { "version": "1.0.0" },
                "dsh-workspace": { "version": "0.2.0" }
              }
            }
            JSON
            git add _sources/lock.json
            git commit -m "Bump lock schema"

            bash ${../../../../scripts/select-package-ci-attrs.sh} "$lock_base" | sort -u > selected-lock-schema
            cmp ${expectedAll} selected-lock-schema
            touch "$out"
          '';
    };
}
