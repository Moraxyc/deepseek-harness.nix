{
  lib,
  pkgsStatic,
  dsh-workspace,
}:
let
  inherit (pkgsStatic) stdenv; # follow upstream
  inherit (stdenv.hostPlatform.node) arch platform;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-landlock-run";
  version = "0.1.1";

  inherit (dsh-workspace) src;

  sourceRoot = "${finalAttrs.src.name}/native/landlock-run";

  buildPhase = ''
    runHook preBuild

    $CC -std=c11 -Os -Wall -Wextra -Werror -static -s \
      packages/entry/src/main.c \
      -o landlock-run

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 landlock-run "$out/bin/landlock-run"
    install -Dm644 packages/entry/src/main.c "$out/share/dsh-landlock-run/main.c"
    install -Dm644 packages/${platform}-${arch}/prebuilds.json "$out/share/dsh-landlock-run/prebuilds.json"

    runHook postInstall
  '';

  meta = {
    description = "Static Landlock self-restrict-then-exec launcher for dsh";
    homepage = "https://github.com/deepseek-ai/deepseek-harness/tree/blob/native/landlock-run";
    license = lib.licenses.bsd3;
    mainProgram = "landlock-run";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
