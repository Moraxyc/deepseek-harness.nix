{ lib, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      # Upstream's switched-off bundles, generated from the pinned source by
      # scripts/generate-optional-bundles.sh; no member is hardcoded below.
      optionalBundlesManifest = lib.importJSON ../../../../pkgs/dsh-workspace/optional-bundles.json;
      optionalBundleNames = lib.attrNames optionalBundlesManifest;
      shipped = pkgs.dsh.dsh.override {
        profiles.web.bundles = [ pkgs.dsh.bundles.web-app ];
      };
      generatorSource = lib.fileset.toSource {
        root = ../../../..;
        fileset = lib.fileset.unions [
          ../../../../scripts/generate-optional-bundles.sh
          ../../../../pkgs/bundles
        ];
      };
    in
    {
      # The committed manifest must match what the generator reads from the
      # pinned source; a parse drift fails here rather than in a later update.
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

            # Node resolves from the nearest node_modules between dir and /.
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
              # The plugin manager lists the bundles the installation manifest declares.
              version=$(jq -r '.version' "$bundleRoot/package.json")
              jq -e --arg name "$name" --arg version "$version" \
                '.dependencies[$name] == $version' "$app/package.json" >/dev/null || {
                printf 'dsh optional bundle is missing from the app manifest or at another version: %s\n' "$name" >&2
                exit 1
              }
              # Enabling it loads the bundle, so its dependencies must resolve.
              while IFS= read -r dependency
              do
                [ -n "$dependency" ] || continue
                resolve_package "$bundleRoot" "$dependency" >/dev/null || {
                  printf 'dsh optional bundle dependency does not resolve: %s -> %s\n' \
                    "$name" "$dependency" >&2
                  exit 1
                }
              done < <(jq -r '.dependencies // {} | keys[]' "$bundleRoot/package.json")
              # Switched off: no shipped profile selects it.
              for manifest in ${shipped.passthru.profileTemplates}/*/package.json
              do
                jq -e --arg name "$name" \
                  '(.dsh.profile.bundles // []) | index($name) == null' "$manifest" >/dev/null || {
                  printf 'managed profile selects optional bundle: %s in %s\n' "$name" "$manifest" >&2
                  exit 1
                }
              done
              # The shared kernel carries no bundle, optional or not.
              if [ -e "$kernelNodeModules/$name" ] || [ -L "$kernelNodeModules/$name" ]; then
                printf 'dsh kernel contains optional bundle: %s\n' "$name" >&2
                exit 1
              fi
              # Every composition ships them; none can leave them out.
              jq -e --arg name "$name" '.dependencies | has($name)' "$defaultApp/package.json" >/dev/null || {
                printf 'default dsh composition lacks optional bundle: %s\n' "$name" >&2
                exit 1
              }
            done
            touch "$out"
          '';
    };
}
