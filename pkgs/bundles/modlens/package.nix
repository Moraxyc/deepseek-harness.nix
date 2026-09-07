{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-modlens";
  version = "3.26.0";
  deployPackage = "@liustack/modlens";

  src = fetchFromGitHub {
    owner = "liustack";
    repo = "modlens";
    tag = "v${finalAttrs.version}";
    hash = "sha256-s4Cjg/v3mI85ZSuOeAEE4O+oLD7ww+ZO9vKjS3P6Dpo=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-SlMlFDdr/Fm8BndcKXCPzwZzmkSsoFp/6yuj5Y2XYDc=";
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
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Plug-in vision for text-only LLMs";
    descriptions.zh-CN = "为纯文本模型提供插件式视觉能力";
    homepage = "https://github.com/liustack/modlens";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
