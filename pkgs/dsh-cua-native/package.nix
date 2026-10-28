{
  lib,
  stdenv,
  swift,
  dsh-workspace,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-cua-native";
  inherit (dsh-workspace) version src;

  sourceRoot = "${finalAttrs.src.name}/packages/experimental/cua-macos/native";
  nativeBuildInputs = [ swift ];
  disallowedReferences = [ swift ];

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    swift build --configuration release --product dsh-cua-native --scratch-path "$TMPDIR/swift-build"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 "$TMPDIR/swift-build/release/dsh-cua-native" "$out/bin/dsh-cua-native"
    runHook postInstall
  '';

  meta = {
    description = "Native macOS Computer Use helper for DeepSeek Harness";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.intersectLists lib.platforms.darwin swift.meta.platforms;
  };
})
