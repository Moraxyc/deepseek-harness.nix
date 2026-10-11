{ lib, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      optionalBundlesManifest = lib.importJSON ../../../../pkgs/dsh-workspace/optional-bundles.json;
      optionalBundleNames = lib.attrNames optionalBundlesManifest;
      shipped = pkgs.dsh.dsh.override {
        profiles.web.bundles = [ pkgs.dsh.bundles.web-app ];
      };
      worktree = pkgs.dsh.dsh.override {
        defaultBundles = [ pkgs.dsh.bundles.headless ];
        profiles.worktree.bundles = with pkgs.dsh.bundles; [
          headless
          experimental-tool-worktree
        ];
      };
      worktreeCheck = pkgs.writeText "dsh-worktree-runtime.mjs" ''
        import assert from 'node:assert/strict'
        import { execFileSync } from 'node:child_process'
        import { mkdtemp, readFile, realpath, writeFile } from 'node:fs/promises'
        import { createRequire } from 'node:module'
        import { tmpdir } from 'node:os'
        import { join } from 'node:path'
        import { Context } from '@deepseek-ai/cordis'
        import LocalFileSystem from '@deepseek-ai/dsh-fs-local'
        import LocalSandbox from '@deepseek-ai/dsh-sandbox-local'
        import SandboxPolicyService from '@deepseek-ai/dsh-sandbox-policy'
        import { Session, SessionId, SESSION_FORMAT_VERSION } from '@deepseek-ai/dsh-session'
        import SessionProjectionRegistry from '@deepseek-ai/dsh-session-projection'
        import LocalSubprocessRuntime from '@deepseek-ai/dsh-subprocess-local'
        import SystemPrompt from '@deepseek-ai/dsh-system-prompt'
        import WorkingDirectoryService from '@deepseek-ai/dsh-working-directory'

        const { default: WorktreeService } = await import(
          createRequire(import.meta.resolve('@deepseek-ai/dsh-experimental-tool-worktree'))
            .resolve('@deepseek-ai/dsh-experimental-worktree'),
        )

        const root = await realpath(await mkdtemp(join(tmpdir(), 'dsh-worktree-')))
        const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim()
        git('init', '-b', 'main')
        git('config', 'user.name', 'Worktree check')
        git('config', 'user.email', 'worktree@example.invalid')
        git('config', 'commit.gpgSign', 'false')
        await writeFile(join(root, 'tracked.txt'), 'committed\n')
        git('add', 'tracked.txt')
        git('commit', '-m', 'initial')
        const baseline = git('rev-parse', 'HEAD')
        await writeFile(join(root, 'tracked.txt'), 'uncommitted\n')

        const ctx = new Context()
        try {
          await ctx.plugin(SessionProjectionRegistry)
          await ctx.plugin(SystemPrompt)
          await ctx.plugin(LocalFileSystem, { cwd: root })
          await ctx.plugin(LocalSubprocessRuntime)
          await ctx.plugin(LocalSandbox)
          await ctx.plugin(SandboxPolicyService, { mode: 'danger-full-access', workspaceRoot: root })
          await ctx.plugin(WorkingDirectoryService)
          await ctx.plugin(WorktreeService, { timeoutMs: 10000 })
          const id = SessionId('worktree-check')
          const session = Session.create(id, [], {
            version: SESSION_FORMAT_VERSION, id, createdAt: 0, isSeeded: false, cwd: root,
          })
          const agent = { ctx, session, inject() {} }
          const policy = structuredClone(ctx.sandboxPolicy.resolve({ session }))
          const created = await ctx.worktrees.create(agent, { name: 'runtime-check' })
          assert.equal(created.path, join(root, '.agents/worktrees/runtime-check'))
          assert.equal(created.baseCommit, baseline)
          assert.equal(await readFile(join(created.path, 'tracked.txt'), 'utf8'), 'committed\n')
          assert.equal(await readFile(join(root, 'tracked.txt'), 'utf8'), 'uncommitted\n')
          assert.equal(ctx.workingDirectory.get(session), created.path)
          assert.deepEqual(ctx.sandboxPolicy.resolve({ session }), policy)
          await assert.rejects(ctx.worktrees.create(agent, { name: 'runtime-check' }), /branch already exists/)
        } finally {
          await ctx.fiber.dispose()
        }
      '';
      generatorSource = lib.fileset.toSource {
        root = ../../../..;
        fileset = lib.fileset.unions [
          ../../../../scripts/generate-optional-bundles.sh
          ../../../../pkgs/bundles
        ];
      };
    in
    {
      checks.dsh-worktree-runtime = pkgs.runCommand "dsh-worktree-runtime" { } ''
        export HOME="$TMPDIR/home"
        export DSH_HOME="$TMPDIR/dsh"
        mkdir -p "$HOME" "$TMPDIR/runtime"
        ${worktree}/bin/dsh --profile nix-worktree --dump-default-config > config.yml
        grep -q '@deepseek-ai/dsh-experimental-worktree' config.yml
        grep -q '@deepseek-ai/dsh-experimental-tool-worktree' config.yml
        ln -s ${worktree}/lib/deepseek-harness/node_modules "$TMPDIR/runtime/node_modules"
        cp ${worktreeCheck} "$TMPDIR/runtime/check.mjs"
        PATH=${lib.escapeShellArg (lib.makeBinPath worktree.passthru.runtimeDeps)} \
          ${lib.getExe pkgs.nodejs-slim} --expose-internals "$TMPDIR/runtime/check.mjs"
        touch "$out"
      '';

      checks.dsh-optional-bundles-generated =
        pkgs.runCommand "dsh-optional-bundles-generated" { nativeBuildInputs = [ pkgs.jq ]; }
          ''
            bash ${generatorSource}/scripts/generate-optional-bundles.sh \
              ${pkgs.dsh.dsh-workspace.src} generated.json
            cmp generated.json ${../../../../pkgs/dsh-workspace/optional-bundles.json}
            touch "$out"
          '';

      checks.dsh-optional-bundles =
        pkgs.runCommand "dsh-optional-bundles" { nativeBuildInputs = [ pkgs.jq ]; }
          ''
            if [ -z "${lib.concatStringsSep " " optionalBundleNames}" ]; then
              printf 'dsh optional bundles: the generated manifest is empty\n' >&2
              exit 1
            fi

            app="${shipped}/lib/deepseek-harness"
            defaultApp="${pkgs.dsh.dsh}/lib/deepseek-harness"
            kernelNodeModules="${pkgs.dsh.dsh-kernel}/lib/deepseek-harness/node_modules"

            resolve_package() {
              local dir=$1 name=$2
              while :; do
                if [ -f "$dir/node_modules/$name/package.json" ]; then
                  printf '%s\n' "$dir/node_modules/$name"
                  return 0
                fi
                [ "$dir" = "/" ] && return 1
                dir=$(dirname "$dir")
              done
            }

            for name in ${lib.escapeShellArgs optionalBundleNames}
            do
              bundleRoot=$(resolve_package "$app" "$name") || {
                printf 'dsh optional bundle does not resolve from the app anchor: %s\n' "$name" >&2
                exit 1
              }
              version=$(jq -r '.version' "$bundleRoot/package.json")
              jq -e --arg name "$name" --arg version "$version" \
                '.dependencies[$name] == $version' "$app/package.json" >/dev/null || {
                printf 'dsh optional bundle is missing from the app manifest or at another version: %s\n' "$name" >&2
                exit 1
              }
              while IFS= read -r dependency
              do
                [ -n "$dependency" ] || continue
                resolve_package "$bundleRoot" "$dependency" >/dev/null || {
                  printf 'dsh optional bundle dependency does not resolve: %s -> %s\n' \
                    "$name" "$dependency" >&2
                  exit 1
                }
              done < <(jq -r '.dependencies // {} | keys[]' "$bundleRoot/package.json")
              for manifest in ${shipped.passthru.profileTemplates}/*/package.json
              do
                jq -e --arg name "$name" \
                  '(.dsh.profile.bundles // []) | index($name) == null' "$manifest" >/dev/null || {
                  printf 'managed profile selects optional bundle: %s in %s\n' "$name" "$manifest" >&2
                  exit 1
                }
              done
              if [ -e "$kernelNodeModules/$name" ] || [ -L "$kernelNodeModules/$name" ]; then
                printf 'dsh kernel contains optional bundle: %s\n' "$name" >&2
                exit 1
              fi
              jq -e --arg name "$name" '.dependencies | has($name)' "$defaultApp/package.json" >/dev/null || {
                printf 'default dsh composition lacks optional bundle: %s\n' "$name" >&2
                exit 1
              }
            done
            touch "$out"
          '';
    };
}
