{
  lib,
  jq,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  python3,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-vision-toolkit";
  version = "0.1.7";
  deployPackage = "@anionex/dsh-vision-toolkit";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "Anionex";
    repo = "dsh-vision-toolkit";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BbhEBc9VXFEOBABG/WIkFZ2zg5EqcbIArIYHHpNaLqc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-o+DCdZLf9KW2ZcIhSciWYQZMCRM9KmVuvRzwtmQ2fkc=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  nativeBuildInputs = [ jq ];
  buildInputs = [ python3 ];

  postDeploy = ''
    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    for entry in "$out"/lib/*; do
      case "$(basename "$entry")" in
        node_modules)
          continue
          ;;
      esac
      mv "$entry" "$deployPackagePath/"
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
