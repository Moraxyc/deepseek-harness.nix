{
  lib,
  buildNpmPackage,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
}:
buildNpmPackage (finalAttrs: {
  pname = "dsh-headless";
  inherit (dsh-kernel) version src pnpmDeps;

  nativeBuildInputs = [ pnpm_11 ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    cd packages/bundle/headless
    mkdir -p $out/lib/node_modules/@deepseek-ai/dsh-headless
    cp -r package.json cordis.patch.yml lib $out/lib/node_modules/@deepseek-ai/dsh-headless/
    ln -s ${dsh-kernel}/lib/deepseek-harness/node_modules \
      $out/lib/node_modules/@deepseek-ai/dsh-headless/node_modules

    runHook postInstall
  '';

  passthru = {
    dshBundles = [ "@deepseek-ai/dsh-headless" ];
  };

  meta = {
    description = "dsh bundle with the core Agent/Session runner";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
