{
  buildNpmPackage,
  gnugrep,
  importNpmLock,
  lib,
  nodejs,
  dsh,
}:
let
  inherit (dsh) catalog;

  catalogSource = builtins.toFile "dsh-nix-docs-catalog.ts" ''
    import type { Catalog } from './catalog';

    export const catalog: Catalog = ${builtins.toJSON catalog};
  '';
in
buildNpmPackage (finalAttrs: {
  pname = "dsh-nix-docs";
  version = (lib.importJSON ../../docs-site/package.json).version;

  inherit nodejs;

  src = lib.fileset.toSource {
    root = ../../docs-site;
    fileset = lib.fileset.unions [
      ../../docs-site/package-lock.json
      ../../docs-site/package.json
      ../../docs-site/react-router.config.ts
      ../../docs-site/src
      ../../docs-site/tsconfig.json
      ../../docs-site/vite.config.ts
    ];
  };

  npmDeps = importNpmLock {
    npmRoot = ../../docs-site;
  };

  npmConfigHook = importNpmLock.npmConfigHook;
  npmBuildScript = "build";
  # React Router prerender binds a local Vite preview server during build.
  __darwinAllowLocalNetworking = true;
  postPatch = "cp ${catalogSource} src/data/catalog.generated.ts";

  installPhase = ''
    cp -r build/client $out
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ gnugrep ];
  installCheckPhase = ''
    runHook preInstallCheck
    for row in ${
      lib.concatStringsSep " " (
        map (bundle: lib.escapeShellArg "bundles.${bundle.name}") catalog.bundles
        ++ map (preset: lib.escapeShellArg "presets.${preset.name}") catalog.presets
      )
    }
    do
      grep -qF "$row" "$out/api/search" || {
        printf 'docs-site: search index lacks %s\n' "$row" >&2
        exit 1
      }
    done
    runHook postInstallCheck
  '';

  meta = {
    description = "DSH Nix documentation site";
    homepage = "https://moraxyc.github.io/deepseek-harness.nix/";
    license = lib.licenses.mit;
    inherit (nodejs.meta) platforms;
  };
})
