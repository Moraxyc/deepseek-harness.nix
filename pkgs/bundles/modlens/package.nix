{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-modlens";
  version = "3.26.5";
  deployPackage = "@liustack/modlens";

  src = fetchFromGitHub {
    owner = "liustack";
    repo = "modlens";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xPy3IMHyL7DqQsd1CFsvcvugi6/uOhN4hlzRVVRDSUE=";
  };

  pnpmDepsHash = "sha256-SlMlFDdr/Fm8BndcKXCPzwZzmkSsoFp/6yuj5Y2XYDc=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  passthru.requiresWeb = true;
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
