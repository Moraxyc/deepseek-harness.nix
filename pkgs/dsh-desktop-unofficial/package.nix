{
  lib,
  callPackage,
  stdenv,
  stdenvNoCC,
  darwin,
  electron,
  makeWrapper,
  wrapGAppsHook3,
  writeShellScriptBin,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  makeDesktopItem,
  copyDesktopItems,
  nix-update,
  writeShellScript,
  nix,
  coreutils,
  gawk,
  gnused,
  yarn-berry_4,
  git,
  imagemagick,
  libGL,

  copyTree,
  dsh,
  # Composed dsh backing resources/host; override with a preset or dsh.override.
  dshHost ? dsh,
  # systemd package providing systemd-run for the Linux containment shim.
  systemd ? null,
}:

let
  inherit (stdenvNoCC.hostPlatform) isLinux isDarwin;

  # DSH's Linux Electron runner is spawned through `systemd-run`, but upstream
  # only sets ELECTRON_RUN_AS_NODE=1 on Windows, so the scope starts the
  # Electron binary in GUI mode instead of Node mode. Shadow systemd-run in the
  # wrapper PATH with this shim: the private runner launched by
  # `runnerEnvironment()` (marked by DSH_SUBPROCESS_RUNNER and the runner entry)
  # gets ELECTRON_RUN_AS_NODE=1; every other systemd-run invocation is
  # untouched.
  useSystemdShim = isLinux && systemd != null;
  systemdRunShim = writeShellScriptBin "systemd-run" ''
    # Every private runner launch needs Electron's Node mode.
    runner=0
    if [ -n "''${DSH_SUBPROCESS_RUNNER-}" ]; then
      case " $* " in
        *" -- "*"/dsh-subprocess-local/"*"/runner.js "*)
          runner=1
          ;;
      esac
    fi
    if [ "$runner" -eq 1 ]; then
      export ELECTRON_RUN_AS_NODE=1
    fi
    exec ${systemd}/bin/systemd-run "$@"
  '';
in
stdenvNoCC.mkDerivation (
  finalAttrs:
  let
    runtimePathArgs = lib.optionalString (
      finalAttrs.passthru.runtimeDeps != [ ]
    ) "--prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} ";
  in
  {
    pname = "dsh-desktop";
    inherit (finalAttrs.passthru.shell) version;

    src = null;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontPatchShebangs = true;

    nativeBuildInputs = [
      makeWrapper
    ]
    ++ lib.optionals isDarwin [
      darwin.autoSignDarwinBinariesHook
    ]
    ++ lib.optionals isLinux [
      wrapGAppsHook3
      copyDesktopItems
      imagemagick
    ];

    buildInputs = lib.optionals isLinux [
      gsettings-desktop-schemas
      glib
      gtk3
    ];

    dontWrapGApps = isLinux;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin"
    ''
    + lib.optionalString isLinux ''
      appDir="$out/lib/dsh-desktop"
      ${copyTree.preserve {
        src = finalAttrs.passthru.shell;
        dest = "$appDir";
      }}

      ${copyTree.preserve {
        src = finalAttrs.passthru.runtime;
        dest = "$appDir/resources/host";
      }}

      gappsWrapperArgsHook
      makeWrapper "$appDir/DeepSeek Harness" "$out/bin/dsh-desktop" \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            libGL
            stdenv.cc.cc.lib
          ]
        } \
        ${runtimePathArgs}\
        --set CHROME_DEVEL_SANDBOX "${electron.unwrapped}/libexec/electron/chrome-sandbox" \
        --inherit-argv0

      for size in 16 22 24 32 48 64 128 256 512; do
        mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
        magick "$appDir/icon.png" -resize "''${size}x''${size}" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/deepseek-harness.png"
      done
    ''
    + lib.optionalString isDarwin ''
      appBundle="$out/Applications/DeepSeek Harness.app"
      mkdir -p "$out/Applications"
      ${copyTree.preserve {
        src = "${finalAttrs.passthru.shell}/DeepSeek Harness.app";
        dest = "$appBundle";
      }}

      ${copyTree.preserve {
        src = finalAttrs.passthru.runtime;
        dest = "$appBundle/Contents/Resources/host";
      }}

      makeWrapper "$appBundle/Contents/MacOS/DeepSeek Harness" "$out/bin/dsh-desktop" \
        ${runtimePathArgs}\
        --inherit-argv0
    ''
    + ''
      runHook postInstall
    '';

    desktopItems = lib.optionals isLinux [
      (makeDesktopItem {
        name = "deepseek-harness";
        desktopName = "DeepSeek Harness";
        exec = "dsh-desktop %U";
        terminal = false;
        icon = "deepseek-harness";
        startupWMClass = "DeepSeek Harness";
        categories = [ "Development" ];
      })
    ];

    passthru = {
      variant = "unofficial";
      shell = callPackage ./shell.nix { };
      runtime = callPackage ./runtime.nix { inherit dshHost; };
      runtimeDeps = lib.optional useSystemdShim systemdRunShim ++ dshHost.passthru.runtimeDeps;

      updateScript = writeShellScript "dsh-desktop-update" ''
        PATH=${
          lib.makeBinPath [
            coreutils
            gawk
            git
            gnused
            nix
            nix-update
            yarn-berry_4.yarn-berry-fetcher
          ]
        }
        export PATH

        set -euo pipefail

        shell_attr="''${UPDATE_NIX_ATTR_PATH:?}.shell"
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT

        nix-update --flake --version=branch --src-only "$shell_attr"

        src="$(nix build --no-link --print-out-paths .#dsh-desktop-unofficial.shell.src)"
        mkdir -p "$tmp/source"
        cp -a "$src/." "$tmp/source/"
        chmod -R u+w "$tmp/source"
        sed -i 's/^  version: 10$/  version: 9/' "$tmp/source/yarn.lock"
        awk '
          /^".*@file:/ { skip = 1; next }
          skip && /^$/ { skip = 0; next }
          !skip { print }
        ' "$tmp/source/yarn.lock" > "$tmp/yarn.lock"

        yarn-berry-fetcher missing-hashes "$tmp/yarn.lock" \
          > "$PWD/pkgs/dsh-desktop-unofficial/missing-hashes.json"

        nix-update --flake --version=skip --no-src "$shell_attr"
      '';
    };

    meta = {
      description = "Unofficial DeepSeek Harness desktop application";
      homepage = "https://github.com/anywhere-labs/deepseek-harness-desktop";
      license = lib.licenses.mit;
      mainProgram = "dsh-desktop";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  }
)
