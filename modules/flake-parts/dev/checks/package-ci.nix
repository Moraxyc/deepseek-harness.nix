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
          *ciPackageAttrs*) ${lib.getExe' pkgs.coreutils "cat"} ${packageSetJson} ;;
          *) exit 1 ;;
        esac
      '';
      select =
        lib.getExe
          (import ../../../../scripts {
            inherit pkgs;
            nix = fixtureNix;
          }).select-package-ci-attrs;
      # Records every call; `pr create` reports pull request 7.
      fakeGh = pkgs.writeShellScriptBin "gh" ''
        printf '%s\n' "$*" >> "$GH_LOG"
        case "$1 $2" in
          "pr create") echo https://github.com/owner/repo/pull/7 ;;
        esac
      '';
      publish =
        lib.getExe
          (import ../../../../scripts {
            inherit pkgs;
            gh = fakeGh;
          }).publish-auto-updates;
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
      checks.dsh-bump-report = config.legacyPackages.tools.dsh-bump-report;
      checks.update-dsh-engines = config.legacyPackages.tools.update-dsh-engines;

      checks.package-ci-selection =
        pkgs.runCommand "package-ci-selection"
          {
            nativeBuildInputs = [ pkgs.gitMinimal ];
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

            ${select} "$base" > selected
            cmp ${expected} selected

            # A fetchrix pin change selects the bundle it belongs to.
            git reset --hard "$base" >/dev/null
            mkdir -p _sources/bundles.tui
            printf '{\n  "schema": 1,\n  "packages": {}\n}\n' > _sources/bundles.tui/pnpm-lock.json
            git add _sources/bundles.tui/pnpm-lock.json
            git commit -m "Update the tui pin"

            ${select} "$base" > selected-bundle
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

            ${select} "$lock_base" > selected-lock-bundle
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

            ${select} "$lock_base" > selected-lock-desktop
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

            ${select} "$lock_base" > selected-lock-workspace
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

            ${select} "$lock_base" > selected-lock-schema
            cmp ${expectedAll} selected-lock-schema

            # Without a base ref, every attr is selected.
            ${select} > selected-all
            cmp ${expectedAll} selected-all
            touch "$out"
          '';

      checks.publish-auto-updates =
        pkgs.runCommand "publish-auto-updates"
          {
            nativeBuildInputs = [
              pkgs.gitMinimal
              pkgs.jq
            ];
          }
          ''
            export HOME=$TMPDIR GH_LOG=$TMPDIR/gh.log PUBLISH_REPORT=$TMPDIR/report.md
            export GITHUB_REPOSITORY=owner/repo GITHUB_SERVER_URL=https://github.com
            git config --global init.defaultBranch main
            git config --global user.name "Publish check"
            git config --global user.email "ci@example.invalid"

            git init -q --bare origin.git
            git clone -q origin.git seed
            cd seed
            printf 'a\n' > a
            printf 'b\n' > b
            git add a b
            git commit -qm base
            git push -q origin main

            # Writes an update that sets FILE to CONTENT, as the update job does.
            update() {
              local name=$1 file=$2 content=$3
              git switch -qC "auto-update/$name" origin/main
              printf '%s\n' "$content" > "$file"
              git commit -qam "$name: update"
              mkdir -p "$TMPDIR/updates/$name"
              git bundle create -q "$TMPDIR/updates/$name/update.bundle" origin/main..HEAD
              jq -n --arg branch "auto-update/$name" --arg title "$name: update" \
                '{branch: $branch, title: $title}' > "$TMPDIR/updates/$name/result.json"
            }
            update 1-a a a2
            update 2-b b b2
            update 3-conflict a a3
            cd ..

            # Reject the first push to main so the batch push has to retry.
            cat > origin.git/hooks/pre-receive <<'HOOK'
            #!${pkgs.runtimeShell}
            while read -r _ _ ref; do
              if [ "$ref" = refs/heads/main ] && [ ! -e rejected-once ]; then
                touch rejected-once
                exit 1
              fi
            done
            HOOK
            chmod +x origin.git/hooks/pre-receive

            git clone -q origin.git work
            (cd work && ${publish} "$TMPDIR/updates")

            [ -e origin.git/rejected-once ]
            [ "$(git -C origin.git show main:a)" = a2 ]
            [ "$(git -C origin.git show main:b)" = b2 ]
            # The conflicting update gets a pull request without CI.
            [ "$(git -C origin.git show auto-update/3-conflict:a)" = a3 ]
            git -C origin.git log -1 --format=%B auto-update/3-conflict | grep -Fqx '[skip ci]'
            grep -q '^pr create .*--head auto-update/3-conflict' "$GH_LOG"
            grep -qx 'pr merge 7 --repo owner/repo --disable-auto' "$GH_LOG"
            [ "$(grep -c '^pr close' "$GH_LOG" || true)" = 0 ]
            grep -qF -- '- auto-update/1-a: published to main' "$PUBLISH_REPORT"
            grep -qF -- '- auto-update/2-b: published to main' "$PUBLISH_REPORT"
            grep -qF -- '- auto-update/3-conflict: [PR #7](https://github.com/owner/repo/pull/7)' "$PUBLISH_REPORT"
            grep -qF 'Combining validated updates caused a conflict. / 合并已验证更新时发生冲突。' "$PUBLISH_REPORT"
            touch "$out"
          '';
    };
}
