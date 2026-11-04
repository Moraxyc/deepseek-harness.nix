{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  source = lib.importJSON ./source.json;
in
stdenvNoCC.mkDerivation {
  pname = "dsh-cua-native";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontConfigure = true;
  dontBuild = true;
  # Fixup strips and rewrites Mach-O files, which would invalidate their signatures.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/dsh-cua-native"
    cp -r native cua-helper.json "$out/lib/dsh-cua-native/"
    runHook postInstall
  '';

  meta = {
    description = "Upstream-signed macOS Computer Use helper for DeepSeek Harness";
    descriptions.zh-CN = "上游签名的 macOS Computer Use 原生助手";
    descriptions.ja = "上流の署名付き macOS Computer Use ヘルパー";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
  };
}
