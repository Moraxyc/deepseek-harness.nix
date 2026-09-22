{
  lib,
  stdenvNoCC,
}:

# Two layers over a runtime node_modules tree, called once on the final tree.
# Neither decides which packages belong in it: that is the package manager's
# production dependency graph (`pnpm deploy --prod`), which also selects the
# platform-specific packages a package declares as optional dependencies.
# Flattening a tree first and pruning afterwards is fine; adding packages after
# a prune is not.
#
#   prune   removes files no runtime can need: documentation, test suites,
#           coverage, node-gyp build leftovers, and the payload a package
#           publishes for platforms the runtime is not.
#
#   minify  removes artifacts a runtime can still read: source maps, typings,
#           TypeScript sources, fixtures and examples. A caller opts in per
#           tree, because only it can accept that risk for its own runtime.
let
  # node-gyp-build and prebuildify resolve `prebuilds/<platform>-<arch>/`, so the
  # host directory is named after the platform triple rather than guessed from
  # whichever directories a package happens to ship.
  hostPrebuildDir = with stdenvNoCC.hostPlatform.node; "${platform}-${arch}";

  # Packages that publish every platform inside one tarball, where the
  # dependency graph has nothing to select. Rules are keyed by package and
  # asserted, so a renamed directory fails the build instead of silently
  # keeping foreign payload or deleting unrelated files. A rule whose package
  # is absent from the tree is skipped.
  platformRules = [
    {
      package = "node-pty";
      # Host prebuilds live among the other systems' prebuilds.
      platformDir = "prebuilds";
      # ConPTY, the Windows pty backend: redistributed binaries and sources.
      drop = [
        "src/win"
        "third_party/conpty"
      ];
    }
  ];

  requirePath = path: description: ''
    [ -e "${path}" ] || {
      printf 'node-modules-prune: missing %s\n' "${description}" >&2
      exit 1
    }
  '';

  prunePlatform =
    tree:
    lib.concatMapStringsSep "\n" (
      rule:
      let
        packageDir = "${tree}/${rule.package}";
        platformDir = "${packageDir}/${rule.platformDir}";
      in
      ''
        if [ -d "${packageDir}" ]; then
          ${requirePath "${platformDir}/${hostPrebuildDir}" "${rule.package}: ${rule.platformDir}/${hostPrebuildDir}"}
          find "${platformDir}" -mindepth 1 -maxdepth 1 -type d \
            ! -name "${hostPrebuildDir}" -exec rm -rf {} +
          ${lib.concatMapStringsSep "\n" (path: ''
            ${requirePath "${packageDir}/${path}" "${rule.package}: ${path}"}
            rm -rf "${packageDir}/${path}"
          '') rule.drop}
        fi
      ''
    ) platformRules;

  dropEmptyDirs = tree: ''find "${tree}" -depth -type d -empty -delete'';
in
{
  prune =
    { tree }:
    ''
      # Creator reads package README files and the Agent Preset skill provider
      # reads its Markdown references and templates at runtime.
      find "${tree}" -type f \
        ! -path "${tree}/@deepseek-ai/dsh-agent-preset/skills/*" \
        ! -iname 'readme*' \( \
        -iname 'changelog*' -o -iname '*.md' -o -iname '*.markdown' \
        -o -name '*.test.js' -o -name '*.test.mjs' -o -name '*.test.cjs' \
        -o -name '*.spec.js' -o -name '*.spec.mjs' -o -name '*.spec.cjs' \
        -o -name 'config.gypi' -o -name 'binding.gyp' -o -name '*.gypi' \
        -o -name '*.target.mk' \
      \) -delete
      ${lib.optionalString (!stdenvNoCC.hostPlatform.isWindows) ''
        find "${tree}" -type f -name '*.pdb' -delete
      ''}
      find "${tree}" -type d \( \
        -name test -o -name tests -o -name __tests__ -o -name coverage \
      \) -prune -exec rm -rf {} +
      ${prunePlatform tree}
      ${dropEmptyDirs tree}
    '';

  minify =
    { tree }:
    ''
      find "${tree}" -type f \( \
        -name '*.map' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \
      \) -delete
      find "${tree}" -type d \( \
        -name fixtures -o -name example -o -name examples \
        -o -name benchmark -o -name benchmarks -o -name demo -o -name demos \
      \) -prune -exec rm -rf {} +
      ${dropEmptyDirs tree}
    '';
}
