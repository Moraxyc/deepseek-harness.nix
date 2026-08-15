{
  lib,
  bubblewrap,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  ripgrep,
  stdenvNoCC,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "dsh-base";
  artifacts = [
    {
      source = "bundles/base";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
  ];
  runtimeDeps = [ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ bubblewrap ];
  meta = {
    description = "Shared dsh core; first layer for profiles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
