# Contributing

## Bundle and preset catalog

The bundle and preset catalogs in `docs/bundles-presets.md` and
`docs/bundles-presets.zh-CN.md` are generated from package metadata by
`nix run .#generate-docs`. Run it after adding, removing, or changing
bundle/preset expressions, and commit the generated files.

Use `nix run .#generate-docs -- --check` to verify the checked-in catalog.
Use `nix run .#generate-docs -- --lang zh-CN` to regenerate only the Chinese
catalog.
The pre-push hook runs this check automatically, and CI regenerates both
catalogs on PRs that touch bundle, preset, or catalog sources.

## Choosing a bundle builder

Use the builder that matches where the bundle source comes from:

- `buildDshBundle`: standalone npm source that must provide its own
  `installPhase` and place the built bundle under `$out/lib/node_modules`.
- `buildDshBundle.fromPnpmWorkspace`: external pnpm monorepo whose selected
  workspace package should be deployed directly into `$out/lib`.
- `buildDshBundle.fromWorkspace`: upstream artifacts already produced by
  `dsh-workspace`, so the bundle package only copies them into `$out`.

Every builder runs the same bundle validation: `$out/lib/node_modules` must
contain at least one package declaring `dsh.bundle.patch`, and the patch file
must exist relative to that package root.

## Adding an external pnpm workspace bundle

Use `buildDshBundle.fromPnpmWorkspace` for external monorepo bundles. It owns
the supported pnpm deploy protocol and produces the standard `$out/lib`
layout directly.

Bundle directory names are the flake output names under `bundles.*`, so strip a
`dsh-` prefix when placing an upstream package under `pkgs/bundles/`. For
example, `dsh-ads` becomes `pkgs/bundles/ads` and `bundles.ads`; the Nix
package `pname` can still keep the upstream name.

Minimal template:

```nix
{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";

  deployPackage = "@example/bundle";
  stripPrepareScripts = true;

  src = fetchFromGitHub {
    owner = "example";
    repo = "example-bundle";
    rev = "0000000000000000000000000000000000000000";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postDeploy = ''
    # Optional bundle-specific layout fixes.
  '';

  meta = {
    description = "Example DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromPnpmWorkspace` runs these operations in the bundle derivation:

1. If `stripPrepareScripts = true`, remove workspace `prepare` scripts before
   deploy so pnpm does not rebuild source packages. This supports both pnpm
   workspaces that use `packages/*` and single-package workspaces that only
   define `packages: ["."]`.
2. Run `pnpm config set --location=project inject-workspace-packages true`.
3. Run:

   ```sh
   pnpm --filter <deployPackage> deploy \
     --prod \
     --config.node-linker=hoisted \
     --config.link-workspace-packages=true \
     "$out/lib"
   ```

Do not use `pnpm ... --legacy`. The injected workspace layout is the supported
protocol. The deploy target is `$out/lib`; do not copy build output back into
the source tree.

For aggregator bundles, set `disableChildBundlePatches = true` so child
`cordis.patch.yml` files are blanked and only `deployPackage` registers loader
entries. If packages need kernel peers such as `@deepseek-ai/dsh-settings`,
pass `linkKernelNodeModules = dsh-kernel`. The helper first removes kernel-owned
packages, including the `@deepseek-ai/*` packages provided by the kernel, from
the bundle output, cleans up dangling `.bin` links, then links the kernel
`node_modules` tree into every package under `$out/lib/node_modules`. This keeps
the kernel as the only runtime provider instead of allowing bundle-local copies
to shadow it.

`postDeploy` can use `$deployPackagePath`, which points at the deployed package
inside `$out/lib/node_modules`. A common aggregator layout fix is:

```sh
rm -rf "$deployPackagePath"
mkdir -p "$deployPackagePath"
mv \
  "$out/lib/package.json" \
  "$out/lib/cordis.patch.yml" \
  "$out/lib/lib" \
  "$deployPackagePath/"
```

Update `src.hash` and `pnpmDeps.hash` with the hashes reported by `nix build`.
The composed `dsh` package runs `dsh --dump-default-config` during
`installCheckPhase`; use that to catch duplicate loader entry IDs, invalid
patches, and missing kernel peer imports before runtime.

`buildDshBundle.fromPnpmWorkspace` automatically excludes `nodejs` and pnpm
from the runtime closure. If a workspace bundle uses `python3` during its
build, add it to `disallowedReferences` in the bundle expression.

## Adding a standalone npm bundle

Use `buildDshBundle` when the source is not a pnpm workspace deploy target.
The derivation must populate `$out/lib/node_modules` itself. Copy the package
manifest, patch file, runtime code, and bundle-specific dependencies into the
package root. Kernel-owned packages are provided by `linkKernelNodeModules`:

```nix
{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "example";
    repo = "example-bundle";
    rev = "0000000000000000000000000000000000000000";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/example-bundle"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  meta = {
    description = "Example standalone DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

If the package needs `pnpmDeps`, `fetchPnpmDeps`, `pnpmConfigHook`, or
`pnpm_11`, add them to the function arguments just like the pnpm workspace
template. `buildDshBundle` does not add pnpm to the runtime closure
automatically, so keep `pnpm_11` in `disallowedReferences` when it is used.

## Adding an upstream workspace bundle

Use `buildDshBundle.fromWorkspace` for bundles built from the pinned
`dsh-workspace` source. The workspace already contains `package.json`,
`cordis.patch.yml`, and `lib` under `packages/bundle/<name>`. Point one
artifact at that source and copy it to the standard node_modules package
path:

```nix
{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "example-workspace-bundle";

  artifacts = [
    {
      source = "bundles/example-workspace-bundle";
      target = "lib/node_modules/@deepseek-ai/${finalAttrs.pname}";
      linkNodeModules = true;
    }
  ];

  runtimeDeps = [ ];

  meta = {
    description = "Example upstream workspace DSH bundle";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromWorkspace` automatically keeps `dsh-workspace` out of the runtime closure.
Set `linkNodeModules = true` when the bundle package expects kernel peers to
resolve from `dsh-kernel`. Use `runtimeDeps` for executable tools that must be
prepended to `PATH` when the composed dsh runs.
