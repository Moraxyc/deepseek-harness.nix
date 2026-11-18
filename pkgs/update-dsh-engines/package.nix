{
  lib,
  ast-grep,
  buildNpmPackage,
  gitMinimal,
  importNpmLock,
  makeBinaryWrapper,
  nix,
  typescript,
}:

buildNpmPackage (finalAttrs: {
  pname = "update-dsh-engines";
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
  nativeCheckInputs = [ ast-grep ];
  checkPhase = ''
    runHook preCheck
    npm test
    runHook postCheck
  '';

  postInstall = ''
    wrapProgram "$out/bin/update-dsh-engines" \
      --set PATH ${
        lib.makeBinPath [
          ast-grep
          gitMinimal
          nix
        ]
      }
  '';

  meta = {
    description = "Raise each bundle's dshEngines grant to the pinned workspace version when its composition still boots";
    license = lib.licenses.mit;
    mainProgram = "update-dsh-engines";
  };
})
