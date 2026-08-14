{
  lib,
  stdenv,
  bubblewrap,
  buildNpmPackage,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  ripgrep,
}:

buildNpmPackage (finalAttrs: {
  pname = "dsh-base";
  inherit (dsh-kernel) version src pnpmDeps;

  nativeBuildInputs = [ pnpm_11 ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    cd packages/bundle/base
    mkdir -p $out/lib/node_modules/@deepseek-ai/dsh-base
    cp -r package.json cordis.patch.yml lib $out/lib/node_modules/@deepseek-ai/dsh-base/
    ln -s ${dsh-kernel}/lib/deepseek-harness/node_modules \
      $out/lib/node_modules/@deepseek-ai/dsh-base/node_modules

    runHook postInstall
  '';

  passthru = {
    dshBundles = [ "@deepseek-ai/dsh-base" ];
    runtimeDeps = [ ripgrep ] ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ];
  };

  meta = {
    description = "Shared dsh core; first layer for profiles";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
