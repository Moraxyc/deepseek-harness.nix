{
  lib,
  buildNpmPackage,
  importNpmLock,
  typescript,
}:

buildNpmPackage (finalAttrs: {
  pname = "generate-optional-bundles";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./tsconfig.json
      ./src
    ];
  };

  npmDeps = importNpmLock { npmRoot = finalAttrs.src; };
  npmConfigHook = importNpmLock.npmConfigHook;

  # From nixpkgs: the npm package carries a native binary for every platform.
  nativeBuildInputs = [ typescript ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    npm test
    runHook postCheck
  '';

  meta = {
    description = "Generate optional-bundles.json from an upstream DeepSeek Harness source tree";
    license = lib.licenses.mit;
    mainProgram = "generate-optional-bundles";
  };
})
