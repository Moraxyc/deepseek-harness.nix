{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  context,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:

let
  betterSidebar = fetchFromGitHub {
    owner = "omdsh-dev";
    repo = "DSH-better-sidebar";
    tag = "v0.9.0";
    hash = "sha256-VQ8lyHNtcTHrOum21Z4dZyZgrxexmUY7yEN8kjao838=";
  };
  contextUnstable = context.overrideAttrs (old: rec {
    version = "0-unstable-2026-08-25";
    src = fetchFromGitHub {
      owner = "bowenliang123";
      repo = "dsh-context";
      rev = "7e522ea342ba3a198b1eaa4557301212ae4098c9";
      hash = "sha256-EK4MHeUABzVBmnCsa8nQzc1j9b75czl/x4Dhatx3oBI=";
    };
    pnpmDeps = fetchPnpmDeps {
      pname = old.pname;
      inherit version src;
      pnpm = pnpm_11;
      fetcherVersion = 4;
      hash = "sha256-39ubS6WWMxKQE/z7f7NaiLQDQ/EIAZ+pg2E11XUlBb0=";
    };
  });
in
buildDshBundle (finalAttrs: {
  pname = "oh-dsh";
  version = "0.1.10";

  src = fetchFromGitHub {
    owner = "hust-open-atom-club";
    repo = "oh-dsh";
    tag = "v${finalAttrs.version}";
    hash = "sha256-hx1InFgOVgwrQgwNE//6jdYae/MbPHuI+M21MDDeW/o=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-HNYXCyWYPOfAtkJdr1wQX7asSsyV9yJCrXNLPfngFwQ=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  postPatch = ''
    mkdir -p upstream/DSH-better-sidebar
    cp -r ${betterSidebar}/. upstream/DSH-better-sidebar/
    chmod -R u+w upstream/DSH-better-sidebar

    mkdir -p upstream/dsh-context
    cp -r ${contextUnstable}/lib/node_modules/dsh-context/. upstream/dsh-context/
    rm -rf upstream/dsh-context/node_modules
    chmod -R u+w upstream/dsh-context
  '';

  installPhase = ''
    runHook preInstall

    bundleRoot="$out/lib/node_modules"
    mkdir -p "$bundleRoot"
    pnpm config set --location=project inject-workspace-packages true
    mkdir -p web/dist
    cp dist/web/index.js dist/web/client.js dist/web/client.js.map dist/web/cordis.patch.yml web/dist/

    for plugin in better-sidebar-runtime skins sidebar panel-controls pinned-summary; do
      mkdir -p "plugins/$plugin/dist"
      cp "dist/plugins/$plugin/index.js" "plugins/$plugin/dist/index.js"
      if [ -f "dist/plugins/$plugin/client.js" ]; then
        cp "dist/plugins/$plugin/client.js" "plugins/$plugin/dist/client.js"
      fi
      if [ -f "dist/plugins/$plugin/client.js.map" ]; then
        cp "dist/plugins/$plugin/client.js.map" "plugins/$plugin/dist/client.js.map"
      fi
    done

    deploy_ohdsh_package() {
      local pkg="$1"
      local name="$2"
      local tmp="$TMPDIR/oh-dsh-deploy-$name"

      rm -rf "$tmp"
      mkdir -p "$tmp"

      pnpm --filter "$pkg" deploy \
        --prod \
        --config.node-linker=hoisted \
        --config.link-workspace-packages=true \
        "$tmp"

      if [ -d "$tmp/node_modules" ]; then
        cp -r "$tmp/node_modules/." "$bundleRoot/"
      fi

      mkdir -p "$bundleRoot/@oh-dsh/$name"
      for entry in "$tmp"/*; do
        [ "$entry" = "$tmp/node_modules" ] && continue
        cp -r "$entry" "$bundleRoot/@oh-dsh/$name/"
      done
      rm -rf "$tmp"
    }

    deploy_ohdsh_package @oh-dsh/web web
    deploy_ohdsh_package @oh-dsh/better-sidebar-runtime better-sidebar-runtime
    deploy_ohdsh_package @oh-dsh/skins skins
    deploy_ohdsh_package @oh-dsh/sidebar sidebar
    deploy_ohdsh_package @oh-dsh/panel-controls panel-controls
    deploy_ohdsh_package @oh-dsh/pinned-summary pinned-summary

    mkdir -p "$bundleRoot/dsh-context"
    cp -r upstream/dsh-context/LICENSE \
      upstream/dsh-context/cordis.patch.yml \
      upstream/dsh-context/package.json \
      upstream/dsh-context/lib \
      "$bundleRoot/dsh-context/"

    find "$bundleRoot" -depth \( -type d -name pnpm -o -type d -name 'pnpm@*' \) -exec rm -rf {} +
    find "$bundleRoot" -depth \( -type f -name pnpm -o -type f -name pnpm.cjs \) -delete
    find "$bundleRoot" -depth -type l -lname '*pnpm*' -delete
    rm -f "$bundleRoot"/@oh-dsh/*/{pnpm-lock,pnpm-workspace}.yaml
    find "$bundleRoot" -path '*/node-pty/build/config.gypi' -delete
    find "$bundleRoot" -path '*/node-pty/build/Makefile' -delete
    find "$bundleRoot" -type f -path '*/node-pty/build/*' ! -name '*.node' -delete
    find "$bundleRoot" -depth -type d -path '*/node-pty/build/*' -empty -delete
    rm -rf "$bundleRoot"/node-pty/{deps,node-addon-api,prebuilds,scripts,src,third_party,typings} \
      "$bundleRoot/node-addon-api"
    find "$bundleRoot" -path '*/node-pty/lib/*.test.js' -delete
    find "$bundleRoot" -path '*/node-pty/lib/*.test.js.map' -delete

    for packageDir in "$bundleRoot"/* "$bundleRoot"/@*/*; do
      [ -d "$packageDir" ] || continue
      if [ ! -e "$packageDir/node_modules" ] && [ ! -L "$packageDir/node_modules" ]; then
        ln -s ${dsh-kernel}/lib/deepseek-harness/node_modules "$packageDir/node_modules"
      fi
    done

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Oh-DSH Web: a packaged DeepSeek Harness browser runtime with Oh-DSH plugin capabilities";
    descriptions.zh-CN = "Oh-DSH Web：带 Oh-DSH 插件能力的 DeepSeek Harness 浏览器运行环境";
    homepage = "https://github.com/hust-open-atom-club/oh-dsh";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
