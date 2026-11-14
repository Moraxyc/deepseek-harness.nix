# Contributing

## Updating packages

```sh
nix develop -c fetchrix update dsh-workspace
nix develop -c fetchrix update bundles.tui
```

`fetchrix.toml` defines version discovery, preparation artifacts, and derived
hashes. `_sources/lock.json` and declared artifacts are consumed through
`dshSources`.
Fetchrix is pinned in the development flake. CI uses the same commands and
skips broken packages.

JSON artifacts handle YAML conversion and field projection. `fetchrixPackages`
binds the new `{ src, version, artifacts }` to existing package definitions;
`derive.select` chooses the FOD, including its normal patch phase. Hooks retain
only DSH-specific preparation.

Commit `_sources/` with the package changes. Fetchrix fingerprints hook programs
and their declared `inputs`; list any other files a hook reads there. Use
`fetchrix verify PACKAGE` to check packaging changes without updating versions.

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

## Installation packages

Bundles are linked into profiles and resolve their peers from the
`dsh-runtime` installation. Set `installation = dsh-runtime` so the helper
replaces copies of its `@deepseek-ai` packages, and same-version copies of
other installation packages, with links into it,
which keeps one runtime instance per package. Use `installationKeep` for
packages the bundle must keep locally. Bundles the installation already
carries use `buildDshBundle.fromInstallation` and are selected by name.
When pnpm deploy removes peer metadata, the helper exposes only the
installation's SDK libraries in that namespace.

## CUA helper

`dsh-cua-native` compiles the Swift helper from `dsh-workspace.src` with the
pinned Nixpkgs toolchain. Upstream's `build_app.py` assembles the release
application and writes `current.json`. The Nix patch replaces its `codesign`
calls with ad-hoc signing through `rcodesign`. The build supports only ad-hoc
signing and fails for any other signing identity or keychain.
Toolchain references are removed before signing. During runtime fixups the
signed generation stays outside the output tree until sealing, so the receipt
matches the signed content.

## Platform notes

- Darwin: `importPnpmLock` aggregates tarballs in bounded batches to stay below
  the sandbox profile size limit.
- The workspace runtime deploys under `$TMPDIR` and then moves to its output,
  because pnpm creates sibling temporary directories.
- aarch64 Linux: aggregate build checks run serially to limit peak memory.
- Tests that bind or resolve localhost set `__darwinAllowLocalNetworking = true`
  and keep the Darwin sandbox enabled.

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
  buildDshBundle,
  pnpmConfigHook,
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

  pnpmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postNormalizeDeploy = ''
    # Optional bundle-specific checks or cleanup.
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
3. `fromPnpmWorkspace` builds `pnpmDeps` from `pnpmDepsHash` with the DSH
   package scope's `fetchPnpmDeps`, which defaults to `pnpmWorkspaceDeploy`.
   `pnpm deploy` with workspace injection needs pnpm 11.22.0 or newer, and the
   deploy step uses the same default, so the template only supplies a hash and
   omits `pnpm`. When nixpkgs ships an older `pnpm_11`, `pnpmWorkspaceDeploy`
   builds 11.22.0 from the npm tarball. Override `pnpm` only for a different,
   still-compatible version. Pass `pnpmDeps` instead of `pnpmDepsHash` only
   when the lockfile needs a custom fetcher, such as `importPnpmLock`. Such a
   bundle declares `pnpm-lock.json` and `pnpm-workspace.json` as fetchrix
   preparation artifacts and passes their `dshSources` paths as `lockfileJson`
   and `workspaceJson`.
4. Run:

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

`pnpm deploy --ignore-scripts` does not build source-only workspace packages.
If the selected package depends on such workspaces, build them in `preDeploy`
(for example, `pnpm --workspace-concurrency=4 --config.ignore-workspace-cycles=true
-r build`) and validate their runtime entrypoints in `postNormalizeDeploy`.

For aggregator bundles, set `disableChildBundlePatches = true` so child
`cordis.patch.yml` files are blanked and only `deployPackage` registers loader
entries.

`postDeploy` runs immediately after `pnpm deploy`, before the builder normalizes
the output layout. Use `postNormalizeDeploy` for checks or cleanup that require
the final package at `$deployPackagePath`. The builder moves the deployed
package files there while keeping the shared `$out/lib/node_modules` tree in
place.

Update `src.hash` and `pnpmDepsHash` with the hashes reported by `nix build`.
The composed `dsh` package boots every managed profile during `installCheckPhase`
through `dshBundleCheckHook`; use that to catch duplicate loader entry IDs,
invalid patches, missing installation peer imports, and package resolution failures
before runtime. Profiles that stay in an interactive terminal loop can set
`requiresTty = true`; the hook runs those under a pseudo-terminal and treats a
live smoke window as a successful boot. The hook also fails when dsh reports
`skipping profile bundle` or `disabling profile plugin`, for example when a
bundle's `engines.dsh` or `@deepseek-ai/dsh-*` peer ranges exclude the pinned
runtime. After verifying such a bundle against that runtime, set
`dshEngines = "<version>"` in its expression; the builder writes it to
`engines.dsh`, and dsh then ignores the peer ranges.
The hook also fails on `failed to import:` or `entries did not activate` in the
log, regardless of the web endpoint's response.

`buildDshBundle.fromPnpmWorkspace` automatically excludes `nodejs` and pnpm
from the runtime closure. If a workspace bundle uses `python3` during its
build, add it to `disallowedReferences` in the bundle expression.

## Adding a standalone npm bundle

Use `buildDshBundle` when the source is not a pnpm workspace deploy target. Its
standard install uses `package.json.name` for the package directory and the
`npm pack` file list for the runtime payload:

```nix
{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";
  installation = dsh-runtime;

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
must place the package under `$out/lib/node_modules`:

```nix
{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";
  installation = dsh-runtime;

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
template. The scoped `fetchPnpmDeps` defaults to the deploy pnpm, so a
standalone bundle that only fetches or builds must pass `pnpm = pnpm_11`.
`buildDshBundle` does not add pnpm to the runtime closure automatically, so
keep `pnpm_11` in `disallowedReferences` when it is used.

## Adding an upstream workspace bundle

Use `buildDshBundle.fromWorkspace` for bundles built from the pinned
`dsh-workspace` source. `dsh-workspace` discovers every upstream manifest with
`dsh.bundle` and deploys that package and its production closure. Select the
deployment by its exact npm `packageName`:

```nix
{
  lib,
  buildDshBundle,
  dsh-runtime,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-workspace;
  pname = "example-workspace-bundle";
  packageName = "@deepseek-ai/example-workspace-bundle";
  installation = dsh-runtime;

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
the runtime closure.

The optional `artifacts` list is only for additional workspace outputs that do
not belong to the npm package, such as a built web frontend. Use `runtimeDeps`
only for executables that must be prepended to `PATH`; npm payloads owned by a
Bundle stay in its deployed closure.

## Client peers from the release cohort

Bundles compile against upstream's published client packages, which the installation
runtime does not carry. `pnpm run release:pack --family dsh` emits their npm
tarballs and `publish-order.txt` as a release cohort.

`pkgs.dsh.dshCohort` (source: `lib/dsh-cohort.nix`) exposes the pack:

The consumed member names are a local list in that file, not an exported
attribute: the cohort is a build output, so the list is declared instead of
being read at evaluation time.

- `select [ ... ]`: a bundle's selection from the declared members, returned as
  scoped npm names. Selecting an undeclared name fails evaluation.
- `installPackages { dest ? "node_modules", names }`: replace the named packages
  under `dest` with the published tarball contents.
- `member name`: the unpacked tarball of one member, with `name` and `version`
  asserted against the workspace release.
- `check`: as `checks.dsh-cohort`, fails when a declared member is absent from the
  pack or from `publish-order.txt`.

A bundle names the peers it compiles against and removes them again when they
must not reach the output:

```nix
let
  clientPackages = dshCohort.select [
    "dsh-client-ui-slots"
    "dsh-client-connection"
  ];
in
...
  preBuild = ''
    ${dshCohort.installPackages { names = clientPackages; }}
  '';

  postBuild = ''
    for clientPackage in ${lib.concatStringsSep " " clientPackages}; do
      rm -rf "node_modules/$clientPackage"
    done
  '';
```

## Bumping dsh-workspace

A runtime bump can build cleanly while dsh skips bundles at runtime. Before and
after updating the pin:

- `scripts/dsh-bump-report.sh NEW_VERSION` compares the pinned and new upstream
  sources: removed packages and exports, bundle rows, official bundle lists,
  build inputs, targets of the local workspace patches, and whether dsh would
  accept each bundle. The auto-update workflow validates the update and pushes
  it to main; when this report lists actions it opens a dsh-workspace pull
  request instead.
- During workspace auto-updates, `scripts/update-dsh-engines.mjs` tries the new
  exact workspace version for buildable bundles that already declare
  `dshEngines`; bundle auto-updates only consider the updated bundle. Each
  candidate must pass its `bundleCompositions` build and sandboxed startup
  check without compatibility exemptions. Failed candidates are restored and
  the update goes to a pull request instead of main. Accepted candidates are
  checked together again before keeping their grants. Other impact-report
  actions keep the update off main as well.
  These checks cover startup and loading, not every feature or provider.
- `scripts/dsh-bundle-probe.sh --all` boots every bundle in its own profile and
  separates bundles that only fail dsh's version check from bundles that fail
  at runtime. The script copies the working tree to the store at startup, so a
  run always tests the tree as it was at startup. Any `broken` result exits with
  status 1.

CI builds `bundleCompositions` alongside the bundles, so a skipped bundle fails
the check.
