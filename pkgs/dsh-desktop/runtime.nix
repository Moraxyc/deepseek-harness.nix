{
  lib,
  stdenvNoCC,
  dshHost,
  jq,
  nodejs-slim,
}:

let
  platformDirNames = [
    "win32*"
    "win-x64"
    "win-arm64"
    "linux*"
    "darwin*"
    "macos*"
    "freebsd*"
    "openbsd*"
    "sunos*"
    "android*"
  ];

  hostPlatformDirNames =
    lib.optional stdenvNoCC.hostPlatform.isLinux "linux*"
    ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [
      "darwin*"
      "macos*"
    ];

  foreignPlatformDirNames = lib.subtractLists hostPlatformDirNames platformDirNames;
  foreignPlatformDirs = lib.concatMapStringsSep " " (
    name: "-o -name '${name}'"
  ) foreignPlatformDirNames;
in
stdenvNoCC.mkDerivation {
  pname = "dsh-desktop-runtime";
  inherit (dshHost) version;

  src = null;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;

  nativeBuildInputs = [
    jq
    nodejs-slim
  ];

  installPhase = ''
    runHook preInstall

    appDir="${dshHost}/lib/deepseek-harness"

    # Break kernel symlinks, then strip build/test/foreign artifacts.
    nm="$out/node_modules"
    mkdir -p "$nm"
    cp -rL "$appDir/node_modules/." "$nm/"
    chmod -R u+w "$nm"

    for bundle in $(jq -r '.bundles[].name' "${dshHost}/nix-support/dsh-bundles.json"); do
      [ -n "$bundle" ] || continue
      if [ -L "$appDir/node_modules/$bundle/node_modules" ]; then
        rm -rf "$nm/$bundle/node_modules"
        ln -s "$nm" "$nm/$bundle/node_modules"
      fi
    done

    find "$nm" -type f \( -name '*.map' -o -name '*.d.ts' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' -o -name '*.pdb' -o -iname 'readme*' -o -iname 'changelog*' -o -iname '*.md' -o -iname '*.markdown' -o -name '*.test.js' -o -name '*.test.mjs' -o -name '*.test.cjs' -o -name '*.spec.js' -o -name '*.spec.mjs' -o -name '*.spec.cjs' -o -name '*.target.mk' -o -name 'config.gypi' -o -name 'binding.gyp' -o -name '*.gypi' \) -delete
    find "$nm" -type d \( -name test -o -name tests -o -name __tests__ -o -name fixtures -o -name example -o -name examples -o -name benchmark -o -name benchmarks -o -name demo -o -name demos -o -name coverage ${foreignPlatformDirs} \) -prune -exec rm -rf {} +
    rm -rf "$nm/.bin" "$nm/vite" "$nm/vitest" "$nm/@vitest" "$nm/typescript" "$nm/esbuild" "$nm/@esbuild" "$nm/rolldown" "$nm/@rolldown" "$nm/lightningcss" "$nm/lightningcss-linux-x64-gnu" "$nm/tsx" "$nm/@testing-library" "$nm/jsdom"
    find "$nm" -depth -type d -empty -delete
    find "$nm" -type l ! -exec test -e {} \; -delete

    mkdir -p "$out/node_modules/@deepseek-ai/dsh"
    cp -rL "$appDir/lib" "$out/node_modules/@deepseek-ai/dsh/lib"
    cp -rL "$appDir/config" "$out/node_modules/@deepseek-ai/dsh/config"
    cp "$appDir/package.json" "$out/node_modules/@deepseek-ai/dsh/package.json"
    cp "$appDir/package.json" "$out/package.json"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    home="$TMPDIR/dsh-runtime-home"
    DSH_HOME="$home" ${lib.getExe nodejs-slim} --expose-internals \
      "$out/node_modules/@deepseek-ai/dsh/lib/bin.js" --version
    DSH_HOME="$home" ${lib.getExe nodejs-slim} --expose-internals \
      "$out/node_modules/@deepseek-ai/dsh/lib/bin.js" web --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Desktop Host runtime assembled from a composed dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
