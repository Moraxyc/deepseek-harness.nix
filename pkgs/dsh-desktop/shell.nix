{
  lib,
  stdenv,
  fetchFromGitHub,
  yarn-berry_4,
  nodejs_22,
  electron_43,
  jq,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-desktop-shell";
  version = "2.0.2-unstable-2026-08-22";

  src = fetchFromGitHub {
    owner = "anywhere-labs";
    repo = "deepseek-harness-desktop";
    rev = "6201080cfaa2f9b0864333e9da695cde71d3f1e1";
    hash = "sha256-7f0eRCpJEy0lcuDFhXtdeYOgl2cvRJj0Qdcz4UxRQqc=";
  };

  postPatch = ''
    sed -i 's/^  version: 10$/  version: 9/' yarn.lock
  '';

  missingHashes = ./missing-hashes.json;

  offlineCache = yarn-berry_4.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes postPatch;
    hash = "sha256-0MmBrkBws/g3FV/TTfuV3PU6ruaISo7As80ytMAqcR4=";
  };

  nativeBuildInputs = [
    yarn-berry_4
    yarn-berry_4.yarnBerryConfigHook
    nodejs_22
    jq
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    YARN_ENABLE_SCRIPTS = "0";
    CI = "true";
  };

  buildPhase = ''
    runHook preBuild

    yarn build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cp -a ${electron_43.dist}/. "$out/"
    chmod -R u+w "$out"
    if [ -d "$out/Electron.app" ]; then
      mv "$out/Electron.app" "$out/DeepSeek Harness.app"
      mv "$out/DeepSeek Harness.app/Contents/MacOS/Electron" "$out/DeepSeek Harness.app/Contents/MacOS/DeepSeek Harness"
      appResources="$out/DeepSeek Harness.app/Contents/Resources"

      substituteInPlace "$out/DeepSeek Harness.app/Contents/Info.plist" \
        --replace '<string>Electron</string>' '<string>DeepSeek Harness</string>' \
        --replace '<string>com.github.Electron</string>' '<string>ai.deepseek.harness.desktop</string>'
    else
      mv "$out/electron" "$out/DeepSeek Harness"
      appResources="$out/resources"
    fi

    mkdir -p "$appResources/app/node_modules"
    cp -rL node_modules/. "$appResources/app/node_modules/"
    chmod -R u+w "$appResources/app/node_modules"

    rm -rf "$appResources/app/node_modules/dsh-plugin-desktop"
    cp -rL dsh-plugin-desktop "$appResources/app/node_modules/dsh-plugin-desktop"
    rm -rf "$appResources/app/node_modules/electron/dist"
    mkdir -p "$appResources/app/node_modules/electron/dist"
    cp -a ${electron_43.dist}/. "$appResources/app/node_modules/electron/dist/"
    chmod -R u+w "$appResources/app/node_modules/electron/dist"
    if [ -d "$appResources/app/node_modules/electron/dist/Electron.app" ]; then
      printf 'Electron.app/Contents/MacOS/Electron\n' > "$appResources/app/node_modules/electron/path.txt"
    else
      printf 'electron\n' > "$appResources/app/node_modules/electron/path.txt"
    fi

    jq -n \
      --arg version "${finalAttrs.version}" \
      '{name:"dsh-desktop", version:$version, type:"module", main:"node_modules/dsh-plugin-desktop/lib/main.js"}' \
      > "$appResources/app/package.json"

    cp dsh-plugin-desktop/build/app-icon.png "$out/icon.png"

    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness Electron shell, uncombined";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ [ "aarch64-darwin" ];
  };
})
