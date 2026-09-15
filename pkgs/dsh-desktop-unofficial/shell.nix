{
  lib,
  stdenv,
  fetchFromGitHub,
  yarn-berry_4,
  nodejs_22,
  electron_43,
  jq,
  writers,
  copyTree,
}:

let
  inherit (stdenv.hostPlatform) isLinux;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-desktop-shell";
  version = "2.0.10-unstable-2026-09-15";

  src = fetchFromGitHub {
    owner = "anywhere-labs";
    repo = "deepseek-harness-desktop";
    rev = "0a9433fafcdcf7930dba8d54cafb6d35edc0f7ab";
    hash = "sha256-/Ft0B55ZdW/eVyvhGsnWQVgos8an8qWjZxYJimZhFyQ=";
  };

  postPatch = ''
    sed -i 's/^  version: 10$/  version: 9/' yarn.lock
  ''
  + lib.optionalString isLinux ''
    # `current` is sufficient on native Linux; Darwin keeps both for universal builds.
    sed -i -E '/^    - (x64|arm64)$/d' .yarnrc.yml
  '';

  missingHashes = ./missing-hashes.json;

  passthru = {
    packageJson = {
      name = "dsh-desktop";
      version = finalAttrs.version;
      type = "module";
      main = "node_modules/dsh-plugin-desktop/lib/main.js";
    };
  };

  offlineCache =
    (yarn-berry_4.fetchYarnBerryDeps {
      inherit (finalAttrs) src missingHashes postPatch;
      hash = "sha256-szHqYuf4lTd8xHIzHsfN/kDydXnNNvC7klA2iw+nGjo=";
    }).overrideAttrs
      (_: {
        buildPhase = ''
          runHook preBuild

          yarnLock=''${yarnLock:=$PWD/yarn.lock}
          filteredLock=$(mktemp)
          awk '
            /^".*@file:/ { skip = 1; next }
            skip && /^$/ { skip = 0; next }
            !skip { print }
          ' "$yarnLock" > "$filteredLock"
          yarn-berry-fetcher fetch "$filteredLock" "$missingHashes"
          cp "$yarnLock" "$out/yarn.lock"

          runHook postBuild
        '';
      });

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

    jq '.workspaces = ["dsh-plugin-desktop", "dsh-community-market"]' \
      package.json > package.json.tmp
    mv package.json.tmp package.json
    for workspace in dsh-plugin-desktop dsh-community-market; do
      jq 'del(.devDependencies)' "$workspace/package.json" \
        > "$workspace/package.json.tmp"
      mv "$workspace/package.json.tmp" "$workspace/package.json"
    done
    YARN_ENABLE_SCRIPTS=0 YARN_ENABLE_IMMUTABLE_INSTALLS=0 \
      yarn install --mode=skip-build

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

    # The yarn workspace links its packages into the project tree.
    ${copyTree.followLinks {
      src = "node_modules";
      dest = "$appResources/app/node_modules";
    }}

    rm -rf "$appResources/app/node_modules/dsh-plugin-desktop"
    ${copyTree.followLinks {
      src = "dsh-plugin-desktop";
      dest = "$appResources/app/node_modules/dsh-plugin-desktop";
    }}
    rm -rf "$appResources/app/node_modules/electron"
    find "$appResources/app/node_modules" -type d \
      \( -name 'test' -o -name 'tests' -o -name '__tests__' \) \
      -prune -exec rm -rf {} +
    cp ${writers.writeJSON "package.json" finalAttrs.passthru.packageJson} \
      "$appResources/app/package.json"

    cp dsh-plugin-desktop/build/app-icon.png "$out/icon.png"

    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness Electron shell, uncombined";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ [ "aarch64-darwin" ];
  };
})
