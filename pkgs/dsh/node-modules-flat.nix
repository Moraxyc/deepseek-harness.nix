{
  lib,
  copyTree,
  stdenvNoCC,

  # Composed node_modules tree (`dsh.passthru.nodeModules`).
  nodeModules,
}:

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

    # find cannot descend into a view's symlinked package directories.
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

    # Copying nested resolution views duplicates the shared tree. Drop only
    # entries resolving to shared packages; retain pinned local copies.
    # Symlinked views break the official desktop's descriptor walker.
    pruneList="$(mktemp)"
    for view in $(find -H "$composed" -mindepth 2 -name node_modules); do
      relative="''${view#"$composed"/}"
      for name in $(viewNames "$view"); do
        if mirrorsShared "$view/$name" "$composed/$name"; then
          printf '%s\n' "$relative/$name" >> "$pruneList"
        fi
      done
    done

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
