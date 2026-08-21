{
  buildNpmPackage,
  importNpmLock,
  lib,
  nodejs,
  dsh,
}:
let
  catalogSource = builtins.toFile "dsh-nix-docs-catalog.ts" ''
    import type { Catalog } from './catalog';

    export const catalog: Catalog = ${builtins.toJSON (import ../../lib/catalog.nix { scope = dsh; })};
  '';
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-nix-docs";
  version = (lib.importJSON ../../docs-site/package.json).version;

  inherit nodejs;

  src = lib.fileset.toSource {
    root = ../../docs-site;
    fileset = lib.fileset.unions [
      ../../docs-site/astro.config.mjs
      ../../docs-site/package-lock.json
      ../../docs-site/package.json
      ../../docs-site/src
      ../../docs-site/tsconfig.json
    ];
  };

  npmDeps = importNpmLock {
    npmRoot = ../../docs-site;
  };

  npmConfigHook = importNpmLock.npmConfigHook;
  npmBuildScript = "build";
  postPatch = "cp ${catalogSource} src/data/catalog.generated.ts";

  installPhase = ''
    cp -r dist $out
  '';

  meta = {
    description = "DSH Nix documentation site";
    homepage = "https://moraxyc.github.io/deepseek-harness.nix/";
    license = lib.licenses.mit;
    inherit (nodejs.meta) platforms;
  };
})
