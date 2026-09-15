{
  lib,
  copyDesktopItems,
  dsh,
  dshHost ? dsh,
  dsh-workspace,
  electron_44,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  makeDesktopItem,
  nodejs-slim,
  pnpmWorkspaceDeploy,
  stdenv,
  stdenvNoCC,
  wrapGAppsHook3,

  dshDesktopPnpm ? pnpmWorkspaceDeploy,
}:

let
  inherit (stdenvNoCC.hostPlatform) isDarwin isLinux parsed;

  # Prebuild directories are named after their target platform, so only the
  # foreign ones can be dropped. A Linux host still resolves either libc, and
  # the architecture is only ever a word-size choice for the same shell.
  hostOs =
    lib.optionals isLinux [
      "linux"
      "musl"
    ]
    ++ lib.optionals isDarwin [
      "darwin"
      "macos"
    ];
  hostArch =
    {
      x86_64 = [
        "x64"
        "x86_64"
      ];
      aarch64 = [
        "arm64"
        "aarch64"
      ];
    }
    .${parsed.cpu.name} or null;

  foreignPlatformDirs = lib.concatMapStringsSep " " (name: "-o -name '${name}'") (
    map (name: "${name}*") (
      lib.subtractLists hostOs [
        "win"
        "android"
        "darwin"
        "linux"
        "macos"
        "musl"
        "freebsd"
        "netbsd"
        "openbsd"
        "sunos"
      ]
    )
    ++ lib.optionals (hostArch != null) (
      lib.concatMap
        (name: [
          "*-${name}"
          "*_${name}"
        ])
        (
          lib.subtractLists hostArch [
            "x64"
            "x86_64"
            "arm64"
            "aarch64"
            "arm"
            "armv7l"
            "ia32"
            "i686"
            "ppc64"
            "ppc64le"
            "s390x"
            "riscv64"
            "loong64"
            "wasm32"
          ]
        )
    )
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-desktop";
  inherit (dshHost) version;

  src = dsh-workspace.desktop;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;

  nativeBuildInputs = [
    copyDesktopItems
    nodejs-slim
    wrapGAppsHook3
  ];

  buildInputs = [
    gsettings-desktop-schemas
    gtk3
  ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/dsh-desktop"
    runtimeRoot="$appDir/resources"
    dshRuntime="$runtimeRoot/app/dsh"
    mkdir -p "$appDir"
    cp -a ${electron_44.dist}/. "$appDir/"
    chmod -R u+w "$appDir"
    mv "$appDir/electron" "$appDir/DeepSeek Harness"
    rm "$runtimeRoot/default_app.asar"

    mkdir -p "$runtimeRoot/app"
    cp -rL "$src/app/"{lib,renderer,node_modules,package.json} "$runtimeRoot/app/"
    chmod -R u+w "$runtimeRoot/app"

    dshPackage="$dshRuntime/node_modules/@deepseek-ai/dsh"
    mkdir -p "$dshPackage"
    cp -rL ${dshHost}/lib/deepseek-harness/{lib,config,package.json} "$dshPackage/"
    cp -rL ${dshHost}/lib/deepseek-harness/node_modules/. "$dshRuntime/node_modules/"
    chmod -R u+w "$dshRuntime"

    cp -rL --update=none "$src/host/node_modules/." "$dshRuntime/node_modules/"
    hostPackage="$dshRuntime/node_modules/@deepseek-ai/dsh-desktop-host"
    mkdir -p "$hostPackage"
    cp -rL "$src/host/lib" "$src/host/config" "$src/host/package.json" "$hostPackage/"
    chmod -R u+w "$dshRuntime"

    # Every bundle carries a nested resolution view that re-lists the whole
    # dependency tree, and cp -rL turns four of them into full copies. An entry
    # resolving to the same package file as the shared tree is reachable one
    # level up once dropped; one resolving elsewhere is a pinned local copy and
    # stays. Linking instead would break the runtime descriptor walker.
    dshNodeModules="${dshHost}/lib/deepseek-harness/node_modules"
    sharedNodeModules="$dshRuntime/node_modules"

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

    views=$(find -H "$dshNodeModules" -mindepth 2 -name node_modules)
    for sourceView in $views; do
      targetView="$sharedNodeModules/''${sourceView#"$dshNodeModules"/}"
      [ -e "$targetView" ] || continue
      for name in $(viewNames "$sourceView"); do
        if mirrorsShared "$sourceView/$name" "$dshNodeModules/$name"; then
          rm -rf "$targetView/$name"
        fi
      done
    done

    # Compiled JavaScript is all that runs here: drop sources, typings, maps,
    # docs, build metadata and test fixtures.
    find "$dshRuntime/node_modules" -type f \( \
      -name '*.map' -o -name '*.d.ts' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \
      -o -name '*.pdb' -o -iname 'readme*' -o -iname 'changelog*' -o -iname '*.md' \
      -o -name '*.test.js' -o -name '*.test.mjs' -o -name '*.test.cjs' \
      -o -name '*.spec.js' -o -name '*.spec.mjs' -o -name '*.spec.cjs' \
      -o -name '*.target.mk' -o -name 'config.gypi' -o -name 'binding.gyp' -o -name '*.gypi' \
    \) -delete
    find "$dshRuntime/node_modules" -type d \( \
      -name test -o -name tests -o -name __tests__ -o -name fixtures \
      -o -name example -o -name examples -o -name benchmark -o -name benchmarks \
      -o -name demo -o -name demos -o -name coverage \
      ${foreignPlatformDirs} \
    \) -prune -exec rm -rf {} +
    find "$dshRuntime/node_modules" -depth -type d -empty -delete

    mkdir -p "$runtimeRoot/runtime"
    ln -s ${dshDesktopPnpm}/libexec/pnpm "$runtimeRoot/runtime/pnpm"

    mkdir -p "$out/bin"
    ln -s "$appDir/DeepSeek Harness" "$out/bin/dsh-desktop"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --suffix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          stdenv.cc.cc.lib
        ]
      }
      --prefix PATH : ${lib.makeBinPath dshHost.passthru.runtimeDeps}
      --set CHROME_DEVEL_SANDBOX "${electron_44.unwrapped}/libexec/electron/chrome-sandbox"
      --inherit-argv0
    )
  '';

  # The descriptor must record the bytes after stdenv's fixups.
  postFixup = ''
    node --input-type=module <<EOF
    import { readFileSync } from 'node:fs';
    import { writeDesktopRuntime } from '$src/app/src/runtime-tree.ts';
    import { DESKTOP_HOST_PROTOCOL_VERSION } from '$src/app/src/host-protocol.ts';

    const root = '$out/lib/dsh-desktop/resources/app/dsh';
    const readPackage = name => JSON.parse(readFileSync(root + '/node_modules/' + name + '/package.json', 'utf8'));
    const dsh = readPackage('@deepseek-ai/dsh');
    const host = readPackage('@deepseek-ai/dsh-desktop-host');
    const sharedNames = [dsh.name, host.name, ...Object.keys(dsh.dependencies), ...Object.keys(host.dependencies)];
    writeDesktopRuntime(root, {
      schemaVersion: 1, version: '${finalAttrs.version}',
      hostProtocolVersion: DESKTOP_HOST_PROTOCOL_VERSION,
      nodeVersion: '${nodejs-slim.version}', pnpmVersion: '${dshDesktopPnpm.version}',
    }, sharedNames);
    EOF
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "deepseek-harness";
      desktopName = "DeepSeek Harness";
      exec = "dsh-desktop %U";
      terminal = false;
      startupWMClass = "DeepSeek Harness";
      categories = [ "Development" ];
    })
  ];

  meta = {
    inherit (dsh-workspace.meta) homepage license;
    description = "DeepSeek Harness Electron desktop application";
    platforms = with lib.platforms; linux;
    mainProgram = "dsh-desktop";
  };
})
