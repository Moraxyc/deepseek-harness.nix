{ lib, ... }:

{
  perSystem =
    { config, pkgs, ... }:
    let
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
    in
    {
      checks.dsh-bump-report = config.legacyPackages.tools.dsh-bump-report;

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
