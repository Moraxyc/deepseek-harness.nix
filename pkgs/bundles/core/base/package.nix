{
  lib,
  bubblewrap,
  buildDshBundle,
  dsh-kernel,
  ripgrep,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel;
  pname = "dsh-base";
  artifacts = [
    {
      source = "bundles/base";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
  ];
  dshBundles = [ "@deepseek-ai/dsh-base" ];
  runtimeDeps = [ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ bubblewrap ];
  meta = {
    description = "Shared dsh core; first layer for profiles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
