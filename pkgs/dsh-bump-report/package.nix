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
  pname = "dsh-bump-report";
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
    wrapProgram "$out/bin/dsh-bump-report" \
      --set PATH ${
        lib.makeBinPath [
          gitMinimal
          nix
        ]
      }
  '';

  meta = {
    description = "Report what a dsh-workspace bump changes for this repository";
    license = lib.licenses.mit;
    mainProgram = "dsh-bump-report";
  };
})
