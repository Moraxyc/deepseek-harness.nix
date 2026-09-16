{
  lib,
  copyDesktopItems,
  copyTree,
  darwin,
  desktopToDarwinBundle,
  dsh,
  dsh-workspace,
  electron,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  makeDesktopItem,
  makeWrapper,
  nodejs-slim,
  pnpmWorkspaceDeploy,
  nodeModulesPrune,
  stdenv,
  stdenvNoCC,
  wrapGAppsHook3,

  dshHost ? dsh,
  dshDesktopPnpm ? pnpmWorkspaceDeploy,
}:

let
  inherit (stdenvNoCC.hostPlatform) isDarwin isLinux;

  appDir = if isDarwin then "$out/Applications/DeepSeek Harness.app" else "$out/lib/dsh-desktop";
  appExecutable =
    if isDarwin then "${appDir}/Contents/MacOS/DeepSeek Harness" else "${appDir}/DeepSeek Harness";
  runtimeRoot = "${appDir}/${if isDarwin then "Contents/Resources" else "resources"}";
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
    makeWrapper
    nodejs-slim
  ]
  ++ lib.optionals isDarwin [
    darwin.autoSignDarwinBinariesHook
    desktopToDarwinBundle
  ]
  ++ lib.optionals isLinux [
    copyDesktopItems
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals isLinux [
    gsettings-desktop-schemas
    gtk3
  ];

  installPhase = ''
    runHook preInstall

    appDir="${appDir}"
    runtimeRoot="${runtimeRoot}"
    dshRuntime="$runtimeRoot/app/dsh"
  ''
  + lib.optionalString isDarwin ''
    mkdir -p "$out/Applications"
    ${copyTree.preserve {
      src = "${electron.dist}/Electron.app";
      dest = "$appDir";
      label = "dsh-desktop: Electron.app is missing";
    }}
    mv "$appDir/Contents/MacOS/Electron" "$appDir/Contents/MacOS/DeepSeek Harness"
    # Use the upstream website logo until the desktop ships its own icon.
    iconTheme=$(mktemp -d)
    install -Dm644 "${dsh-workspace.src}/website/public/favicon.svg" \
      "$iconTheme/icons/hicolor/scalable/apps/dsh.svg"
    convertIconTheme "$runtimeRoot" "$iconTheme" dsh
    rm "$runtimeRoot/electron.icns"
    substituteInPlace "$appDir/Contents/Info.plist" \
      --replace-fail '<string>electron.icns</string>' '<string>dsh.icns</string>' \
      --replace-fail '<string>Electron</string>' '<string>DeepSeek Harness</string>' \
      --replace-fail '<string>com.github.Electron</string>' '<string>ai.deepseek.harness.desktop</string>'
  ''
  + lib.optionalString isLinux ''
    ${copyTree.preserve {
      src = electron.dist;
      dest = "$appDir";
      label = "dsh-desktop: Electron distribution is missing";
    }}
    mv "$appDir/electron" "$appDir/DeepSeek Harness"
  ''
  + ''
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
  ''
  + lib.optionalString isDarwin ''
    makeWrapper "${appExecutable}" "$out/bin/dsh-desktop" \
      --prefix PATH : ${lib.makeBinPath dshHost.passthru.runtimeDeps} \
      --inherit-argv0
  ''
  + lib.optionalString isLinux ''
    ln -s "${appExecutable}" "$out/bin/dsh-desktop"
  ''
  + ''
    runHook postInstall
  '';

  preFixup = ''
    sealDesktopRuntime() {
      node --input-type=module <<EOF
    import { readFileSync } from 'node:fs';
    import { writeDesktopRuntime } from '$src/app/src/runtime-tree.ts';
    import { DESKTOP_HOST_PROTOCOL_VERSION } from '$src/app/src/host-protocol.ts';

    const root = '${runtimeRoot}/app/dsh';
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
    }
    postFixupHooks+=(sealDesktopRuntime)
  ''
  + lib.optionalString isLinux ''
    gappsWrapperArgs+=(
      --suffix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          stdenv.cc.cc.lib
        ]
      }
      --prefix PATH : ${lib.makeBinPath dshHost.passthru.runtimeDeps}
      --set CHROME_DEVEL_SANDBOX "${electron.unwrapped}/libexec/electron/chrome-sandbox"
      --inherit-argv0
    )
  '';

  desktopItems = lib.optional isLinux (makeDesktopItem {
    name = "deepseek-harness";
    desktopName = "DeepSeek Harness";
    exec = "dsh-desktop %U";
    terminal = false;
    startupWMClass = "DeepSeek Harness";
    categories = [ "Development" ];
  });

  meta = {
    inherit (dsh-workspace.meta) homepage license;
    description = "DeepSeek Harness Electron desktop application";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "dsh-desktop";
  };
})
