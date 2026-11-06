# Android launchers have no maskable icon to crop, so the PWA installs with a
# white square. Ship prebuilt maskable variants of the whale alongside the
# manifest entries; see
# https://github.com/deepseek-ai/deepseek-harness/discussions/4962
{
  lib,
  imagemagick,
  jq,
}:
frontend: ''
  # Render the 50px SVG above target size; 60% fits the maskable safe zone.
  for size in 192 512; do
    iconSize=$((size * 3 / 5))
    ${lib.getExe imagemagick} \
      -background none \
      -density 1536 \
      "${frontend}/dist/favicon.svg" \
      -resize "''${iconSize}x''${iconSize}" \
      -gravity center \
      -background none \
      -extent "''${size}x''${size}" \
      -depth 8 -strip \
      "${frontend}/dist/dsh-maskable-''${size}.png"
  done

  ${lib.getExe jq} '.icons += [
    {"src":"/dsh-maskable-192.png","sizes":"192x192","type":"image/png","purpose":"maskable"},
    {"src":"/dsh-maskable-512.png","sizes":"512x512","type":"image/png","purpose":"maskable"}
  ]' "${frontend}/dist/manifest.webmanifest" > "${frontend}/dist/manifest.webmanifest.new"
  mv "${frontend}/dist/manifest.webmanifest.new" "${frontend}/dist/manifest.webmanifest"
''
