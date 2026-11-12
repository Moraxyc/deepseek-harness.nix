{
  lib,
  apple-sdk,
  dsh-workspace,
  python3,
  removeReferencesTo,
  rcodesign,
  replaceVars,
  stdenv,
  swiftPackages,
}:

let
  platformKey = with stdenv.hostPlatform.node; "${platform}-${arch}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-cua-native";
  inherit (dsh-workspace) src version;

  sourceRoot = "${finalAttrs.src.name}/packages/experimental/cua-macos/native";
  strictDeps = true;
  disallowedReferences = [
    stdenv.cc
    apple-sdk
  ];
  dontConfigure = true;
  # Fixup rewrites Mach-O files and would invalidate the signature applied in installPhase.
  dontFixup = true;

  patches = [
    (replaceVars ./nix-signing.patch {
      rcodesign = lib.getExe rcodesign;
    })
  ];

  nativeBuildInputs = [
    python3
    swiftPackages.swift
    swiftPackages.swiftpm
    swiftPackages.swiftpmHook
  ];
  swiftpmFlags = [
    "--product"
    "dsh-cua-native"
  ];

  postBuild = ''
    ${lib.getExe removeReferencesTo} -t ${stdenv.cc} -t ${apple-sdk} \
      "$(swiftpmBinPath)/dsh-cua-native"
  '';

  installPhase = ''
    runHook preInstall

    python3 - "$(swiftpmBinPath)/dsh-cua-native" \
      "$out/lib/dsh-cua-native/native/bin/${platformKey}" <<'PY'
    import sys
    from pathlib import Path
    from build_app import publish

    publish(Path(sys.argv[1]), Path(sys.argv[2]), "-", Path("Info.plist"))
    PY

    runHook postInstall
  '';

  meta = {
    description = "Source-built macOS Computer Use helper for DeepSeek Harness";
    descriptions.zh-CN = "从源码构建的 macOS Computer Use 原生辅助程序";
    descriptions.ja = "ソースからビルドする macOS Computer Use ヘルパー";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
})
