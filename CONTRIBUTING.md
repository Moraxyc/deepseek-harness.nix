# Contributing

## Choosing a bundle builder

Use the builder that matches where the bundle source comes from:

- `buildDshBundle`: standalone npm source installed with `buildNpmPackage`'s
  standard `npmInstallHook` unless it needs a custom layout.
- `buildDshBundle.fromPnpmWorkspace`: external pnpm monorepo whose selected
  workspace package should be deployed directly into `$out/lib`.
- `buildDshBundle.fromWorkspace`: an upstream package and its production
  closure already deployed by `dsh-workspace`.

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
to shadow it. If a bundle depends on its own version of a package that also
exists in the kernel, list it in `linkKernelNodeModulesKeep` so the helper keeps
the bundle-local copy.

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
The composed `dsh` package boots every managed profile during `installCheckPhase`
through `dshBundleCheckHook`; use that to catch duplicate loader entry IDs,
invalid patches, missing kernel peer imports, and package resolution failures
before runtime. Profiles that stay in an interactive terminal loop can set
`requiresTty = true`; the hook runs those under a pseudo-terminal and treats a
live smoke window as a successful boot.

`buildDshBundle.fromPnpmWorkspace` automatically excludes `nodejs` and pnpm
from the runtime closure. If a workspace bundle uses `python3` during its
build, add it to `disallowedReferences` in the bundle expression.

## Adding a standalone npm bundle

Use `buildDshBundle` when the source is not a pnpm workspace deploy target. Its
standard install uses `package.json.name` for the package directory and the
`npm pack` file list for the runtime payload. Kernel-owned packages are
provided by `linkKernelNodeModules`:

```nix
{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
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

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  npmBuildScript = "build";

  meta = {
    description = "Example standalone DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

The package manifest must include `cordis.patch.yml` and the runtime build
output in its npm package payload. Override `installPhase` only when the npm
package layout cannot represent the required runtime output; a custom phase
must place the package under `$out/lib/node_modules`.

If the package needs `pnpmDeps`, `fetchPnpmDeps`, `pnpmConfigHook`, or
`pnpm_11`, add them to the function arguments just like the pnpm workspace
template. `buildDshBundle` does not add pnpm to the runtime closure
automatically, so keep `pnpm_11` in `disallowedReferences` when it is used.

## Adding an upstream workspace bundle

Use `buildDshBundle.fromWorkspace` for bundles built from the pinned
`dsh-workspace` source. `dsh-workspace` discovers every upstream manifest with
`dsh.bundle` and deploys that package and its production closure. Select the
deployment by its exact npm `packageName`:

```nix
{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "example-workspace-bundle";
  packageName = "@deepseek-ai/example-workspace-bundle";
  linkKernelNodeModules = dsh-kernel;

  runtimeDeps = [ ];

  meta = {
    description = "Example upstream workspace DSH bundle";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromWorkspace` copies the complete deployment into the standard
`$out/lib/node_modules/<packageName>` layout and keeps `dsh-workspace` out of
the runtime closure. Use `linkKernelNodeModules = dsh-kernel` to deduplicate
kernel-owned packages and satisfy kernel peers. `linkKernelNodeModulesKeep`
retains an intentional bundle-local version of a kernel package.

The optional `artifacts` list is only for additional workspace outputs that do
not belong to the npm package, such as a built web frontend. Use `runtimeDeps`
only for executables that must be prepended to `PATH`; npm payloads owned by a
Bundle stay in its deployed closure.
