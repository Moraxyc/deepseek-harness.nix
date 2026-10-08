{
  lib,
  stdenvNoCC,
}:

# Prune the final production dependency tree, after all packages are added.
# Package selection belongs to the package manager, not these file filters.
# minify also removes runtime-readable artifacts; callers must accept that risk.
let
  # node-gyp-build and prebuildify resolve `prebuilds/<platform>-<arch>/`.
  hostPrebuildDir = with stdenvNoCC.hostPlatform.node; "${platform}-${arch}";

  # The dependency graph cannot filter foreign payload within one tarball.
  # Assert each path before deleting it so layout changes fail the build.
  platformRules = [
    {
      package = "node-pty";
      platformDir = "prebuilds";
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
