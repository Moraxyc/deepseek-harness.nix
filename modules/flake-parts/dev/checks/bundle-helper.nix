{ ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      bundleName = "dsh-bundle-helper-check";
      bundleSource = ./fixtures/bundle-helper-npm;
      bundle = pkgs.dsh.helpers.buildBundle (_finalAttrs: {
        pname = bundleName;
        version = "1.0.0";

        src = bundleSource;
        npmDeps = pkgs.importNpmLock { npmRoot = bundleSource; };
        npmConfigHook = pkgs.importNpmLock.npmConfigHook;
        dontBuild = true;

        postInstall = ''
          packageRoot="$out/lib/node_modules/${bundleName}"
          test -f "$packageRoot/dist/index.js"
          test -f "$packageRoot/node_modules/@sinclair/typebox/package.json"
          test ! -e "$packageRoot/node_modules/@standard-schema/spec"
        '';

        meta.description = "External bundle helper regression check";
      });

      workspacePackageName = "dsh-pnpm-workspace-check";
      workspaceDependencyName = "dsh-pnpm-workspace-check-dependency";
      workspaceSrc = pkgs.runCommand "${workspacePackageName}-source" { } ''
        mkdir -p "$out/packages/app" "$out/packages/dependency"
        cp ${
          pkgs.writeText "package.json" (
            builtins.toJSON {
              name = "${workspacePackageName}-root";
              private = true;
              version = "1.0.0";
            }
          )
        } "$out/package.json"
        cp ${pkgs.writeText "pnpm-workspace.yaml" ''
          packages:
            - packages/*
        ''} "$out/pnpm-workspace.yaml"
        cp ${pkgs.writeText "pnpm-lock.yaml" ''
          lockfileVersion: '9.0'
          settings:
            autoInstallPeers: true
            excludeLinksFromLockfile: false
          importers:
            .: {}
            packages/app:
              dependencies:
                ${workspaceDependencyName}:
                  specifier: workspace:*
                  version: link:../dependency
            packages/dependency: {}
        ''} "$out/pnpm-lock.yaml"
        cp ${
          pkgs.writeText "package.json" (
            builtins.toJSON {
              name = workspacePackageName;
              version = "1.0.0";
              dependencies.${workspaceDependencyName} = "workspace:*";
              dsh.bundle.patch = "./cordis.patch.yml";
            }
          )
        } "$out/packages/app/package.json"
        cp ${pkgs.writeText "index.js" "export default true;\n"} "$out/packages/app/index.js"
        cp ${pkgs.writeText "cordis.patch.yml" "[]\n"} "$out/packages/app/cordis.patch.yml"
        cp ${
          pkgs.writeText "package.json" (
            builtins.toJSON {
              name = workspaceDependencyName;
              version = "1.0.0";
              main = "index.js";
            }
          )
        } "$out/packages/dependency/package.json"
        cp ${pkgs.writeText "index.js" "export default true;\n"} "$out/packages/dependency/index.js"
      '';
      workspaceBundle = pkgs.dsh.helpers.buildBundle.fromPnpmWorkspace (_finalAttrs: {
        pname = workspacePackageName;
        version = "1.0.0";
        deployPackage = workspacePackageName;

        src = workspaceSrc;
        npmDeps = null;
        npmConfigHook = pkgs.pnpmConfigHook;
        dontConfigure = true;
        dontBuild = true;

        preInstall = "pnpm install --offline --frozen-lockfile";
        postDeploy = ''
          dependencyPath="$out/lib/node_modules/${workspaceDependencyName}"
          resolvedDependency=$(readlink -f "$dependencyPath")
          case "$resolvedDependency" in
            "$out"/*)
              ;;
            *)
              printf 'deployed workspace dependency escapes the output: %s\n' "$resolvedDependency" >&2
              exit 1
              ;;
          esac

          mkdir -p "$deployPackagePath"
          mv \
            "$out/lib/package.json" \
            "$out/lib/index.js" \
            "$out/lib/cordis.patch.yml" \
            "$deployPackagePath/"
        '';

        meta.description = "pnpm workspace bundle helper regression check";
      });
    in
    {
      checks.dsh-bundle-helper = pkgs.linkFarm "dsh-bundle-helper-checks" [
        {
          name = "basic";
          path = bundle;
        }
        {
          name = "pnpm-workspace";
          path = workspaceBundle;
        }
      ];
    };
}
