{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
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
