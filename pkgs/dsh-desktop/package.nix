{
  lib,
  callPackage,
  stdenv,
  stdenvNoCC,
  electron_43,
  makeWrapper,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  gtk4,
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
  systemdRunShim = stdenvNoCC.mkDerivation {
    pname = "dsh-systemd-run-shim";
    version = "1";

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontPatchShebangs = true;

    installPhase = ''
            runHook preInstall
            mkdir -p "$out/bin"
            cat > "$out/bin/systemd-run" <<'EOF'
      #!${stdenvNoCC.shell}
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
      EOF
            chmod +x "$out/bin/systemd-run"
            runHook postInstall
    '';

    meta.description = "systemd-run shim that fixes DSH's Linux Electron runner";
  };
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
    ++ lib.optionals isLinux [
      wrapGAppsHook3
      copyDesktopItems
      imagemagick
    ];

    buildInputs = lib.optionals isLinux [
      gsettings-desktop-schemas
      glib
      gtk3
      gtk4
    ];

    dontWrapGApps = isLinux;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin"
    ''
    + lib.optionalString isLinux ''
      appDir="$out/lib/dsh-desktop"
      mkdir -p "$appDir"
      cp -a ${finalAttrs.passthru.shell}/. "$appDir/"
      chmod -R u+w "$appDir"

      mkdir -p "$appDir/resources/host"
      cp -a ${finalAttrs.passthru.runtime}/. "$appDir/resources/host/"

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
        --set CHROME_DEVEL_SANDBOX "${electron_43.unwrapped}/libexec/electron/chrome-sandbox" \
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
      cp -a "${finalAttrs.passthru.shell}/DeepSeek Harness.app" "$appBundle"
      chmod -R u+w "$appBundle"

      mkdir -p "$appBundle/Contents/Resources/host"
      cp -a "${finalAttrs.passthru.runtime}/." "$appBundle/Contents/Resources/host/"

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
      shell = callPackage ./shell.nix { };
      runtime = callPackage ./runtime.nix { inherit dshHost; };
      runtimeDeps = dshHost.passthru.runtimeDeps ++ lib.optionals useSystemdShim [ systemdRunShim ];

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

        src="$(nix build --no-link --print-out-paths .#dsh-desktop.shell.src)"
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
          > "$PWD/pkgs/dsh-desktop/missing-hashes.json"

        nix-update --flake --version=skip --no-src "$shell_attr"
      '';
    };

    meta = {
      description = "DeepSeek Harness desktop application";
      homepage = "https://github.com/anywhere-labs/deepseek-harness-desktop";
      license = lib.licenses.mit;
      mainProgram = "dsh-desktop";
      platforms = with lib.platforms; linux ++ darwin;
    };
  }
)
