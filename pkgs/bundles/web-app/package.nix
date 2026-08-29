{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  imagemagick,
  jq,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-web-app";
  packageName = "@deepseek-ai/dsh-web-app";
  linkKernelNodeModules = dsh-kernel;
  artifacts = [
    {
      source = "frontends/web";
      target = "lib/node_modules/@deepseek-ai/dsh-web-frontend";
    }
  ];

  # Android launchers have no maskable icon to crop, so the PWA installs with
  # a white square. Ship prebuilt maskable variants of the whale alongside the
  # manifest entries; see
  # https://github.com/deepseek-ai/deepseek-harness/discussions/4962
  nativeBuildInputs = [
    imagemagick
    jq
  ];
  postInstall = ''
    frontend="$out/lib/node_modules/@deepseek-ai/dsh-web-frontend"

    # Render the 50px SVG above target size; 60% fits the maskable safe zone.
    for size in 192 512; do
      iconSize=$((size * 3 / 5))
      magick \
        -background none \
        -density 1536 \
        "$frontend/dist/favicon.svg" \
        -resize "''${iconSize}x''${iconSize}" \
        -gravity center \
        -background none \
        -extent "''${size}x''${size}" \
        -depth 8 -strip \
        "$frontend/dist/dsh-maskable-''${size}.png"
    done

    jq '.icons += [
      {"src":"/dsh-maskable-192.png","sizes":"192x192","type":"image/png","purpose":"maskable"},
      {"src":"/dsh-maskable-512.png","sizes":"512x512","type":"image/png","purpose":"maskable"}
    ]' "$frontend/dist/manifest.webmanifest" > "$frontend/dist/manifest.webmanifest.new"
    mv "$frontend/dist/manifest.webmanifest.new" "$frontend/dist/manifest.webmanifest"
  '';

  passthru.requiresWeb = true;
  meta = {
    description = "Web interface for dsh";
    descriptions.zh-CN = "dsh 的网页界面";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
