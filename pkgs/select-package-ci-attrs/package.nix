{
  lib,
  buildNpmPackage,
  gitMinimal,
  importNpmLock,
  makeBinaryWrapper,
  nix,
  typescript,
}:

buildNpmPackage (finalAttrs: {
  pname = "select-package-ci-attrs";
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

  nativeBuildInputs = [
    makeBinaryWrapper
    # From nixpkgs: the npm package carries a native binary for every platform.
    typescript
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    npm test
    runHook postCheck
  '';

  postInstall = ''
    wrapProgram "$out/bin/select-package-ci-attrs" \
      --set PATH ${
        lib.makeBinPath [
          gitMinimal
          nix
        ]
      }
  '';

  meta = {
    description = "Print the package attrs CI builds for the changes since a base ref";
    license = lib.licenses.mit;
    mainProgram = "select-package-ci-attrs";
  };
})
