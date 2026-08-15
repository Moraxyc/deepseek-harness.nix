{
  lib,
  callPackage,
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
  nix-update-script,
  imagemagick,
  libGL,

  dsh,
  # Composed dsh backing resources/host; override with a preset or dsh.override.
  dshHost ? dsh,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-desktop";
  inherit (finalAttrs.passthru.shell) version;

  src = null;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook3
    copyDesktopItems
    imagemagick
  ];

  buildInputs = [
    gsettings-desktop-schemas
    glib
    gtk3
    gtk4
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/dsh-desktop"
    mkdir -p "$appDir"
    cp -a ${finalAttrs.passthru.shell}/. "$appDir/"
    chmod -R u+w "$appDir"

    mkdir -p "$appDir/resources/host"
    cp -a ${finalAttrs.passthru.runtime}/. "$appDir/resources/host/"

    gappsWrapperArgsHook

    mkdir -p "$out/bin"
    makeWrapper "$appDir/DeepSeek Harness" "$out/bin/dsh-desktop" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL ]} \
      ${
        lib.optionalString (
          finalAttrs.passthru.runtimeDeps != [ ]
        ) "--prefix PATH : ${lib.makeBinPath finalAttrs.passthru.runtimeDeps} "
      }\
      --set CHROME_DEVEL_SANDBOX "${electron_43.unwrapped}/libexec/electron/chrome-sandbox" \
      --inherit-argv0

    for size in 16 22 24 32 48 64 128 256 512; do
      mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
      magick "$appDir/icon.png" -resize "''${size}x''${size}" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/deepseek-harness.png"
    done

    runHook postInstall
  '';

  desktopItems = [
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
    runtimeDeps = dshHost.passthru.runtimeDeps;

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--version=branch"
        "--subpackage=shell"
      ];
    };
  };

  meta = {
    description = "DeepSeek Harness desktop application";
    homepage = "https://github.com/anywhere-labs/deepseek-harness-desktop";
    license = lib.licenses.mit;
    mainProgram = "dsh-desktop";
    platforms = lib.platforms.linux;
  };
})
