{
  lib,
  apple-sdk,
  stdenv,
  stdenvNoCC,

  copyDesktopItems,
  copyTree,
  darwin,
  desktopToDarwinBundle,
  makeDesktopItem,
  makeWrapper,
  nodeModulesPrune,
  wrapGAppsHook3,
  writers,

  dsh,
  dsh-workspace,
  electron,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  nodejs-slim,
  pnpmWorkspaceDeploy,
  removeReferencesTo,
  python3,
  python3Packages,
  xcbuild,

  dshHost ? dsh,
  desktopProfile ? null,
  dshDesktopPnpm ? pnpmWorkspaceDeploy,
}:

let
  inherit (stdenvNoCC.hostPlatform) isDarwin isLinux;

  appDir = if isDarwin then "$out/Applications/DeepSeek Harness.app" else "$out/lib/dsh-desktop";
  appExecutable =
    if isDarwin then "${appDir}/Contents/MacOS/DeepSeek Harness" else "${appDir}/DeepSeek Harness";
  runtimeRoot = "${appDir}/${if isDarwin then "Contents/Resources" else "resources"}";
  pythonEnv = python3.withPackages (
    ps: with ps; [
      numpy
      pandas
      python-docx
      python-pptx
      openpyxl
      pillow
      lxml
      xlsxwriter
      python-dateutil
      six
      tzdata
      typing-extensions
      et-xmlfile
    ]
  );
  desktopRuntimeDeps = [ pythonEnv ] ++ lib.remove dshDesktopPnpm dshHost.passthru.runtimeDeps;
  storeReferencesToStrip = lib.optionals isDarwin [
    stdenv.cc
    apple-sdk
  ];
  storeReferenceArgs = lib.concatMapStringsSep " " (
    reference: "-t ${lib.escapeShellArg reference}"
  ) storeReferencesToStrip;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-desktop";
  inherit (dshHost) version;

  src = dsh-workspace.desktop;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;
  disallowedReferences = storeReferencesToStrip;

  nativeBuildInputs = [
    makeWrapper
    nodejs-slim
  ]
  ++ lib.optionals isDarwin [
    xcbuild # for plutil
    removeReferencesTo
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

    plist="$appDir/Contents/Info.plist"
    plutil -replace CFBundleExecutable  -string "DeepSeek Harness"          "$plist"
    plutil -replace CFBundleIconFile    -string dsh.icns                    "$plist"
    plutil -replace CFBundleName        -string "DeepSeek Harness"          "$plist"
    plutil -replace CFBundleDisplayName -string "DeepSeek Harness"          "$plist"
    plutil -replace CFBundleIdentifier  -string ai.deepseek.harness.desktop "$plist"
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
    cp ${writers.writeJSON "dsh-desktop-nix-profile.json" desktopProfile} "$runtimeRoot/app/nix-profile.json"

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

    # Alpha.2 loads the Office skills from an external resource directory;
    # copy them before pruning node_modules, which removes Markdown files.
    ${copyTree.followLinks {
      src = "$src/host/node_modules/@deepseek-ai/dsh-skill-office/assets";
      dest = "$runtimeRoot/runtime/office-skills";
      label = "dsh-desktop: Office skill assets are missing";
    }}

    ${nodeModulesPrune.prune { tree = "$dshRuntime/node_modules"; }}
    ${nodeModulesPrune.minify { tree = "$dshRuntime/node_modules"; }}

    hostPackage="$dshRuntime/node_modules/@deepseek-ai/dsh-desktop-host"
    ${copyTree.followLinks {
      src = "$src/host/lib";
      dest = "$hostPackage/lib";
    }}
    cp "$src/host/package.json" "$hostPackage/package.json"

    mkdir -p "$runtimeRoot/runtime/bin"
    ln -s "${dshDesktopPnpm}/libexec/pnpm" "$runtimeRoot/runtime/pnpm"
    ln -s "${nodejs-slim}/bin/node" "$runtimeRoot/runtime/bin/node"

    primaryRuntime="$runtimeRoot/runtime/primary-runtime"
    mkdir -p "$primaryRuntime/dependencies/node/bin" "$primaryRuntime/dependencies/node/node_modules"
    ln -s "${nodejs-slim}/bin/node" "$primaryRuntime/dependencies/node/bin/node"
    printf '%s\n' 'Reserved for bundled Node packages.' > "$primaryRuntime/dependencies/node/node_modules/README.txt"
    ln -s "${dshDesktopPnpm}/libexec/pnpm" "$primaryRuntime/dependencies/pnpm"
    ln -s "${pythonEnv}" "$primaryRuntime/dependencies/python"
    install -Dm644 ${
      writers.writeJSON "dsh-desktop-primary-runtime.json" {
        desktopVersion = finalAttrs.version;
        platform = if isDarwin then "darwin" else "linux";
        arch = stdenvNoCC.hostPlatform.node.arch;
        pythonPackages = {
          numpy = python3Packages.numpy.version;
          pandas = python3Packages.pandas.version;
          python-docx = python3Packages.python-docx.version;
          python-pptx = python3Packages.python-pptx.version;
          openpyxl = python3Packages.openpyxl.version;
          Pillow = python3Packages.pillow.version;
          lxml = python3Packages.lxml.version;
          XlsxWriter = python3Packages.xlsxwriter.version;
          python-dateutil = python3Packages.python-dateutil.version;
          six = python3Packages.six.version;
          tzdata = python3Packages.tzdata.version;
          typing_extensions = python3Packages.typing-extensions.version;
          et_xmlfile = python3Packages.et-xmlfile.version;
        };
        components = {
          python = python3.version;
          node = nodejs-slim.version;
          pnpm = dshDesktopPnpm.version;
          numpy = python3Packages.numpy.version;
          pandas = python3Packages.pandas.version;
        };
      }
    } "$primaryRuntime/runtime.json"
    install -Dm644 ${
      writers.writeJSON "dsh-desktop-runtime-versions.json" {
        schemaVersion = 1;
        node = nodejs-slim.version;
        pnpm = dshDesktopPnpm.version;
      }
    } "$runtimeRoot/runtime/versions.json"
    chmod 755 "$runtimeRoot/runtime/office-skills/scripts/check_office.py"

    mkdir -p "$out/bin"
  ''
  + lib.optionalString isDarwin ''
    makeWrapper "${appExecutable}" "$out/bin/dsh-desktop" \
      --set DSH_DESKTOP_RUNTIME_MODE bundled \
      --prefix PATH : "${runtimeRoot}/runtime/bin" \
      --prefix PATH : ${lib.makeBinPath desktopRuntimeDeps} \
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
  ''
  + lib.optionalString isDarwin ''
    stripRuntimeReferences() {
      find "$out" -type f -exec ${lib.getExe removeReferencesTo} ${storeReferenceArgs} {} +
    }
    # Rewrite binaries before signing, then record their final bytes.
    postFixupHooks=(stripRuntimeReferences "''${postFixupHooks[@]}")
  ''
  + ''
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
     --set CHROME_DEVEL_SANDBOX "${appDir}/chrome-sandbox"
      --set DSH_DESKTOP_RUNTIME_MODE bundled
      --prefix PATH : "${runtimeRoot}/runtime/bin"
      --prefix PATH : ${lib.makeBinPath desktopRuntimeDeps}
      --inherit-argv0
    )
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    node --input-type=module <<EOF
    import { verifyDesktopRuntime } from '$src/app/src/runtime-tree.ts';
    await verifyDesktopRuntime('${runtimeRoot}/app/dsh', '${finalAttrs.version}');
    EOF

    runHook postInstallCheck
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
