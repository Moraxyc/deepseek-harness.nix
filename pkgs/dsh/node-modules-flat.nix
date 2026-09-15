{
  lib,
  copyTree,
  stdenvNoCC,

  # Composed node_modules tree (`dsh.passthru.nodeModules`).
  nodeModules,
}:

# Turns the composed tree into one that resolves without the stores it was
# assembled from. Pruning is a separate step: a consumer that adds packages
# after this one has to strip the final tree, not this one.
stdenvNoCC.mkDerivation {
  name = "dsh-node-modules-flat";

  src = null;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    nm="$out/node_modules"
    composed="${nodeModules}"

    # Package names in a view, one scope level expanded: find cannot descend
    # into the symlinked package directories a view is built from.
    viewNames() {
      local name sub
      for name in $(ls -A "$1"); do
        case "$name" in
          @*)
            for sub in $(ls -A "$1/$name"); do
              echo "$name/$sub"
            done
            ;;
          *) echo "$name" ;;
        esac
      done
    }

    mirrorsShared() {
      # Bookkeeping entries (.bin, .pnpm, .modules.yaml) are small and may hold
      # per-install state, so only real package directories are compared.
      [ -e "$1/package.json" ] && [ -e "$2/package.json" ] \
        && [ "$(readlink -f "$1/package.json")" = "$(readlink -f "$2/package.json")" ]
    }

    # Every bundle carries a nested resolution view that re-lists the whole
    # dependency tree, and copying the tree below turns each of them into a
    # full copy. The views are read off the composed tree, where they are still
    # symlinks, so readlink -f reports the kernel tree both sides resolve to: an
    # entry mirroring the shared tree is reachable one level up once dropped,
    # while one resolving elsewhere is a pinned local copy and stays. Linking
    # the views instead would break the descriptor walker in
    # pkgs/dsh-desktop-official.
    pruneList="$(mktemp)"
    for view in $(find -H "$composed" -mindepth 2 -name node_modules); do
      relative="''${view#"$composed"/}"
      for name in $(viewNames "$view"); do
        if mirrorsShared "$view/$name" "$composed/$name"; then
          printf '%s\n' "$relative/$name" >> "$pruneList"
        fi
      done
    done

    # Following the links here is what produces a tree that survives without
    # the stores it was composed from.
    ${copyTree.followLinks {
      src = nodeModules;
      dest = "$out/node_modules";
    }}

    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      rm -rf "$nm/$entry"
    done < "$pruneList"
    find "$nm" -depth -type d -empty -delete

    runHook postInstall
  '';
}
