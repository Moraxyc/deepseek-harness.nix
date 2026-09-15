{
  lib,
  copyDesktopItems,
  copyTree,
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
  nodeModulesPrune,
  stdenv,
  stdenvNoCC,
  wrapGAppsHook3,

  dshDesktopPnpm ? pnpmWorkspaceDeploy,
}:

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
    ${copyTree.preserve {
      src = electron_44.dist;
      dest = "$appDir";
    }}
    mv "$appDir/electron" "$appDir/DeepSeek Harness"
    rm "$runtimeRoot/default_app.asar"

    # The renderer app tree comes from the desktop workspace, which links its
    # dependencies into the pnpm store.
    ${lib.concatMapStringsSep "\n"
      (
        entry:
        copyTree.followLinks {
          src = "$src/app/${entry}";
          dest = "$runtimeRoot/app/${entry}";
        }
      )
      [
        "lib"
        "renderer"
        "node_modules"
      ]
    }
    cp "$src/app/package.json" "$runtimeRoot/app/package.json"

    dshPackage="$dshRuntime/node_modules/@deepseek-ai/dsh"
    ${copyTree.followLinks {
      src = "${dshHost}/lib/deepseek-harness/lib";
      dest = "$dshPackage/lib";
    }}
    ${copyTree.followLinks {
      src = "${dshHost}/lib/deepseek-harness/config";
      dest = "$dshPackage/config";
    }}
    cp "${dshHost}/lib/deepseek-harness/package.json" "$dshPackage/package.json"

    # The composed tree is flattened once in dsh.passthru.flattenedNodeModules:
    # a bundle resolution view that mirrors the shared tree is already dropped,
    # so this stays one copy of the runtime dependency tree.
    ${copyTree.preserve {
      src = "${dshHost.passthru.flattenedNodeModules}/node_modules";
      dest = "$dshRuntime/node_modules";
    }}

    # Host dependencies only fill in names the runtime does not ship.
    ${copyTree.fillMissing {
      src = "$src/host/node_modules";
      dest = "$dshRuntime/node_modules";
    }}

    # Compiled JavaScript is all that runs here. `prune` drops what no runtime
    # reads; `minify` additionally drops sources, typings, maps and fixtures
    # from package payloads, which this runtime accepts because nothing loads
    # them at run time. Both run before the app and host packages are copied in:
    # their `config` directories hold data the runtime reads, such as agent
    # preset skills and composition examples.
    ${nodeModulesPrune.prune { tree = "$dshRuntime/node_modules"; }}
    ${nodeModulesPrune.minify { tree = "$dshRuntime/node_modules"; }}

    hostPackage="$dshRuntime/node_modules/@deepseek-ai/dsh-desktop-host"
    ${copyTree.followLinks {
      src = "$src/host/lib";
      dest = "$hostPackage/lib";
    }}
    ${copyTree.followLinks {
      src = "$src/host/config";
      dest = "$hostPackage/config";
    }}
    cp "$src/host/package.json" "$hostPackage/package.json"

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
