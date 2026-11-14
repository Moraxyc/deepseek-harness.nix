{
  lib,
  dshSources,
  buildDshBundle,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-modlens";
  inherit (dshSources."bundles.modlens") version src;
  deployPackage = "@liustack/modlens";

  pnpmDepsHash = dshSources."bundles.modlens".pnpmDepsHash;

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  passthru.requiresWeb = true;

  meta = {
    description = "Plug-in vision for text-only LLMs";
    descriptions.zh-CN = "为纯文本模型提供插件式视觉能力";
    descriptions.ja = "テキスト専用 LLM にプラグイン形式で視覚機能を提供";
    homepage = "https://github.com/liustack/modlens";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
