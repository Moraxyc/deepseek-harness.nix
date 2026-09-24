{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  pnpmConfigHook,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-modlens";
  version = "3.26.4";
  deployPackage = "@liustack/modlens";

  src = fetchFromGitHub {
    owner = "liustack";
    repo = "modlens";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XSGfwhtkrqfnPKH0tyPAQypWR+akWN9gm8CxPXXeCAc=";
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
