{
  lib,
  dsh-workspace,
  nodejs-slim,
  pkgsStatic,
  stdenv,
}:

let
  inherit (stdenv.hostPlatform) isDarwin isLinux;
  inherit (stdenv.hostPlatform.node) arch platform;
  staticCc = lib.optionalString isLinux "${pkgsStatic.stdenv.cc}/bin/${pkgsStatic.stdenv.cc.targetPrefix}gcc";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-system";
  version = "0.1.2";

  inherit (dsh-workspace) src;

  sourceRoot = "${finalAttrs.src.name}/native/system";

  nativeBuildInputs = [ nodejs-slim ];
  disallowedReferences = [ nodejs-slim ];

  buildPhase = ''
    runHook preBuild
  ''
  + lib.optionalString isLinux ''
    # Upstream's build script expects the conventional musl-gcc name.
    mkdir -p "$NIX_BUILD_TOP/upstream-bin"
    ln -s ${staticCc} "$NIX_BUILD_TOP/upstream-bin/musl-gcc"
    PATH="$NIX_BUILD_TOP/upstream-bin:$PATH" \
      ${nodejs-slim}/bin/node --experimental-strip-types scripts/build.ts
  ''
  + lib.optionalString isDarwin ''
    ${nodejs-slim}/bin/node --experimental-strip-types scripts/build.ts
  ''
  + ''
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
  ''
  + lib.optionalString isLinux ''
    install -Dm755 packages/${platform}-${arch}/bin/landlock-run "$out/bin/landlock-run"
    install -Dm644 packages/${platform}-${arch}/bin/glibc/system.node "$out/bin/glibc/system.node"
    install -Dm644 packages/${platform}-${arch}/bin/musl/system.node "$out/bin/musl/system.node"
  ''
  + lib.optionalString isDarwin ''
    install -Dm644 packages/${platform}-${arch}/bin/system.node "$out/bin/system.node"
  ''
  + ''
    install -Dm644 packages/entry/src/main.c "$out/share/dsh-system/main.c"
    install -Dm644 packages/entry/src/flock.c "$out/share/dsh-system/flock.c"
    install -Dm644 packages/${platform}-${arch}/prebuilds.json \
      "$out/share/dsh-system/prebuilds.json"

    runHook postInstall
  '';

  meta = {
    description = "Prebuilt Landlock launcher and system primitives for dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness/tree/dsh-v${dsh-workspace.version}/native/system";
    license = lib.licenses.bsd3;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
})
