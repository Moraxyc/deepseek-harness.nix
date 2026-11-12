{
  lib,
  apple-sdk,
  stdenv,
  stdenvNoCC,

  bashInteractive,
  bubblewrap,
  copyTree,
  darwin,
  dsh-workspace,
  gh,
  gitMinimal,
  nodeModulesPrune,
  nodejs,
  nodejs-slim,
  pnpmWorkspaceDeploy,
  removeReferencesTo,
  ripgrep,
  webMaskableIcons,
}:

let
  inherit (stdenvNoCC.hostPlatform) isDarwin isLinux;
  pnpm = pnpmWorkspaceDeploy;

  storeReferencesToStrip = lib.optionals isDarwin [
    stdenv.cc
    apple-sdk
  ];
in
# The upstream installation shared by the CLI and Desktop: @deepseek-ai/dsh,
# its official bundles, and the private Desktop Host, sealed as one tree.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-runtime";
  inherit (dsh-workspace) version;

  src = dsh-workspace.runtime;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;
  disallowedReferences = [ nodejs ] ++ storeReferencesToStrip;

  nativeBuildInputs = [
    nodejs-slim
  ]
  ++ lib.optionals isDarwin [
    darwin.autoSignDarwinBinariesHook
    removeReferencesTo
  ];

  installPhase = ''
    runHook preInstall

    ${copyTree.followLinks {
      src = "$src/node_modules";
      dest = "$out/node_modules";
    }}
    rm -rf "$out/node_modules/.bin" "$out/node_modules"/.modules.yaml "$out/node_modules"/.pnpm*

    ${webMaskableIcons "$out/node_modules/@deepseek-ai/dsh-web-frontend"}
    node "$out/node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs"

    ${nodeModulesPrune.prune { tree = "$out/node_modules"; }}
    ${nodeModulesPrune.minify { tree = "$out/node_modules"; }}

    runHook postInstall
  '';

  preFixup = ''
    sealDesktopRuntime() {
      node --input-type=module <<EOF
    import { readFileSync } from 'node:fs';
    import { writeDesktopRuntime } from '${dsh-workspace.desktop}/app/src/runtime-tree.ts';
    import { DESKTOP_HOST_PROTOCOL_VERSION } from '${dsh-workspace.desktop}/app/src/host-protocol.ts';

    const root = '$out';
    const readPackage = name => JSON.parse(readFileSync(root + '/node_modules/' + name + '/package.json', 'utf8'));
    const dsh = readPackage('@deepseek-ai/dsh');
    const host = readPackage('@deepseek-ai/dsh-desktop-host');
    const sharedNames = [dsh.name, host.name, ...Object.keys(dsh.dependencies), ...Object.keys(host.dependencies)];
    writeDesktopRuntime(root, {
      schemaVersion: 1, version: '${finalAttrs.version}',
      hostProtocolVersion: DESKTOP_HOST_PROTOCOL_VERSION,
      nodeVersion: '${nodejs-slim.version}', pnpmVersion: '${pnpm.version}',
    }, sharedNames);
    EOF
    }
  ''
  + lib.optionalString isDarwin ''
    # Keep the signed CUA generation outside all mutating fixup hooks.
    cuaBin="$out/node_modules/@deepseek-ai/dsh-experimental-cua-macos/native/bin"
    mv "$cuaBin" "$TMPDIR/cua-bin"
    restoreCuaApplication() {
      mv "$TMPDIR/cua-bin" "$cuaBin"
    }
    stripRuntimeReferences() {
      find "$out" -type f -exec ${lib.getExe removeReferencesTo} ${
        lib.concatMapStringsSep " " (reference: "-t ${lib.escapeShellArg reference}") storeReferencesToStrip
      } {} +
    }
    # Rewrite binaries before signing, then record their final bytes.
    postFixupHooks=(stripRuntimeReferences "''${postFixupHooks[@]}" restoreCuaApplication)
  ''
  + ''
    postFixupHooks+=(sealDesktopRuntime)
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for path in \
      dsh/docs/user/index.md \
      dsh/docs/upgrade-guide/README.md \
      dsh/src/bin.ts \
      dsh-agent-preset/skills/dsh-doc/SKILL.md \
      dsh-agent-preset/skills/dsh-doc/references/locate-docs.md; do
      test -f "$out/node_modules/@deepseek-ai/$path" || {
        printf 'dsh-runtime: missing documentation resource: %s\n' "$path" >&2
        exit 1
      }
    done

  ''
  + lib.optionalString isDarwin ''
    diff -r \
      ${dsh-workspace.runtime}/node_modules/@deepseek-ai/dsh-experimental-cua-macos/native/bin \
      "$out/node_modules/@deepseek-ai/dsh-experimental-cua-macos/native/bin"
  ''
  + ''
    runHook postInstallCheck
  '';

  passthru = {
    inherit pnpm;
    # Commands the bundled tools and official bundles invoke.
    runtimeDeps = [
      bashInteractive
      gh
      gitMinimal
      nodejs-slim
      pnpm
      ripgrep
    ]
    ++ lib.optionals isLinux [ bubblewrap ];
  };

  meta = {
    inherit (dsh-workspace.meta) homepage license;
    description = "DeepSeek Harness installation shared by the CLI and Desktop";
    platforms = lib.platforms.unix;
  };
})
