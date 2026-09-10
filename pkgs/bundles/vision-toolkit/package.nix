{
  lib,
  jq,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  pnpmConfigHook,
  python3,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-vision-toolkit";
  version = "0.1.44";
  deployPackage = "@anionex/dsh-vision-toolkit";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Anionex";
    repo = "dsh-vision-toolkit";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Yr1PAzyMqro6P+w+aiixJ1stDt2drjORlo0pOy5Rd6o=";
  };

  pnpmDepsHash = "sha256-u6xB0c6k3SOlblxDcGRNSVNcVipVkpFkclMg58z4YwQ=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  disallowedReferences = [ dsh-workspace ];

  nativeBuildInputs = [ jq ];
  buildInputs = [ python3 ];

  postNormalizeDeploy = ''
    webRuntime="${dsh-workspace}/lib/dsh-workspace/runtime-bundles/@deepseek-ai/dsh-web-app/node_modules"
    for clientPackage in \
      dsh-api-remotes \
      dsh-client-connection \
      dsh-client-locale \
      dsh-client-ui-attachment \
      dsh-client-ui-conversation \
      dsh-client-ui-input-trigger \
      dsh-client-ui-settings \
      dsh-client-ui-tool \
      dsh-session-stats \
      dsh-typert-protocol; do
      packageDir="$out/lib/node_modules/@deepseek-ai/$clientPackage"
      source="$webRuntime/@deepseek-ai/$clientPackage"
      [ -d "$source" ] || {
        printf 'dsh-vision-toolkit: workspace runtime package is missing: %s\n' "$source" >&2
        exit 1
      }
      rm -rf "$packageDir"
      cp -rL "$source" "$packageDir"
      chmod -R u+w "$packageDir"
    done

    while IFS= read -r -d $'\0' script; do
      patchShebangs "$script"
    done < <(find "$deployPackagePath/vendor/agent-vision-toolkit" \
      -type f -perm /111 -print0)

    vendorRoot="$deployPackagePath/vendor/agent-vision-toolkit"
    manifest="$vendorRoot/UPSTREAM_MANIFEST.json"
    manifestTmp="$(mktemp)"
    entriesLines="$(mktemp)"
    entriesFile="$(mktemp)"
    rowsFile="$(mktemp)"
    jq -r '.files[].path' "$manifest" | while IFS= read -r path; do
      file="$vendorRoot/$path"
      bytes="$(wc -c < "$file")"
      sha="$(sha256sum "$file" | cut -d' ' -f1)"
      jq -nc \
        --arg path "$path" \
        --argjson bytes "$bytes" \
        --arg sha "$sha" \
        '{path:$path, bytes:$bytes, sha256:$sha}' >> "$entriesLines"
      printf '%s\0%s\n' "$path" "$sha" >> "$rowsFile"
    done
    jq -s . "$entriesLines" > "$entriesFile"
    jq --slurpfile entries "$entriesFile" \
      '.files = $entries[0]' "$manifest" > "$manifestTmp"
    content="$(sha256sum "$rowsFile" | cut -d' ' -f1)"
    chmod +w "$manifest"
    jq --arg content "$content" \
      '.contentSha256 = $content' "$manifestTmp" > "$manifest"
    rm -f "$manifestTmp" "$entriesLines" "$entriesFile" "$rowsFile"

    rm -rf "$out/lib/node_modules/.pnpm"
    find "$out/lib/node_modules" -depth -type d -name .bin -exec rm -rf {} +
    find "$out/lib/node_modules" -depth -type d -empty -delete
  '';

  passthru.requiresWeb = true;
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "DeepSeek Harness-native vision toolkit with OCR, grounding, pixel diff, and UI restoration";
    descriptions.zh-CN = "DeepSeek Harness 原生视觉工具集，支持 OCR、定位、像素差异与 UI 还原";
    homepage = "https://github.com/Anionex/dsh-vision-toolkit";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
