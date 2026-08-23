{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchgit,
  fetchPnpmDeps,
  runCommand,
  writeText,
  pnpm,
}:
let
  defaultPnpm = pnpm;
in
{
  # pnpm-lock.yaml converted to JSON
  lockfileJson,
  # Additional dependency entries to merge into pnpm lockfile importers.
  # Values use the lockfile importer format with `specifier` and `version`.
  importerDependencyOverrides ? { },
  pnpm ? null,
  fetcherVersion ? null,
  pname ? null,
  registry ? "https://registry.npmjs.org",
  # Escape hatch like importNpmLock's packageSourceOverrides. Keys may contain
  # `*` wildcards; exact keys take precedence over the longest matching
  # wildcard key. Values may be source paths or functions receiving
  # { pkg, previousSource, patchPackageSource }.
  packageSourceOverrides ? { },
  # SRI content hashes for git dependencies, keyed by lockfile package id.
  # Example: gitHashes."foo@git+https://..." = "sha256-...";
  gitHashes ? { },
  # Extra options forwarded to the fetcher used for a package, keyed by
  # lockfile package id (mirrors importNpmLock's fetcherOpts).
  fetcherOpts ? { },
  # Patch files for lockfile patchedDependencies, keyed by lockfile package id.
  # Example: patchedDependencySources."node-pty@1.2.0-beta.15" = ./node-pty.patch;
  patchedDependencySources ? { },
  # Optional target platform, such as stdenv.targetPlatform, for filtering
  # platform-specific packages.
  targetPlatform ? null,
  ...
}:
let
  inherit (lib)
    elem
    listToAttrs
    nameValuePair
    concatStringsSep
    mapAttrsToList
    head
    init
    last
    elemAt
    hasPrefix
    substring
    stringLength
    splitString
    removeSuffix
    ;

  lockfile = builtins.fromJSON (builtins.readFile lockfileJson);
  pnpmPkg = if pnpm != null then pnpm else defaultPnpm;

  effectiveTargetPlatform =
    if targetPlatform == null then
      null
    else
      {
        os = targetPlatform.node.platform;
        cpu = targetPlatform.node.arch;
        libc = if targetPlatform.isLinux then targetPlatform.libc else null;
      };

  effectivePname = if pname != null then pname else "pnpm-deps";
  effectiveFetcherVersion = if fetcherVersion != null then fetcherVersion else 4;

  packageKey =
    id:
    let
      withoutPeer = head (splitString "(" id);
      slashInfo =
        if hasPrefix "/" withoutPeer then
          let
            parts = splitString "/" (substring 1 ((stringLength withoutPeer) - 1) withoutPeer);
          in
          if hasPrefix "@" (head parts) then
            {
              name = "${elemAt parts 0}/${elemAt parts 1}";
              version = elemAt parts 2;
            }
          else
            {
              name = elemAt parts 0;
              version = elemAt parts 1;
            }
        else
          null;
      nameVersion = splitString "@" withoutPeer;
      version = last nameVersion;
      name = concatStringsSep "@" (init nameVersion);
      baseName = last (splitString "/" name);
    in
    if slashInfo != null then
      slashInfo
      // {
        inherit id;
        baseName = last (splitString "/" slashInfo.name);
      }
    else
      {
        inherit
          id
          name
          version
          baseName
          ;
      };

  platformFieldMatches =
    values: target:
    if target == null || values == null then
      true
    else
      let
        values' = if builtins.isList values then values else [ values ];
        allowed = lib.filter (value: !hasPrefix "!" value) values';
        excluded = lib.filter (value: hasPrefix "!" value) values';
      in
      !(elem "!${target}" excluded) && (allowed == [ ] || elem target allowed);

  makePackage =
    id: v:
    let
      info = packageKey id;
      name = v.name or info.name;
      version = v.version or info.version;
      baseName = last (splitString "/" name);
      meta = info // {
        inherit name version baseName;
        os = v.os or null;
        cpu = v.cpu or null;
        libc = v.libc or null;
      };
      resolution = v.resolution or { };
      integrity = resolution.integrity or "";
    in
    if resolution ? directory then
      throw "importPnpmLock: local package `${id}` needs application source; not supported from the lockfile alone"
    else if (resolution.type or "") == "git" then
      meta
      // {
        kind = "git";
        gitUrl = resolution.repo;
        gitRev = resolution.commit;
      }
    else if resolution ? tarball then
      meta
      // {
        kind = "tarball";
        url = resolution.tarball;
        inherit integrity;
      }
    else if v ? id then
      let
        split = splitString "/" v.id;
      in
      meta
      // {
        kind = "git";
        gitUrl = "https://${concatStringsSep "/" (init split)}.git";
        gitRev = last split;
      }
    else if resolution ? integrity then
      meta
      // {
        kind = "registry";
        url = "${removeSuffix "/" registry}/${name}/-/${baseName}-${version}.tgz";
        inherit integrity;
      }
    else
      throw "importPnpmLock: no fetchable resolution for `${id}`";

  packages = lib.attrValues (lib.mapAttrs makePackage (lockfile.packages or { }));

  packageMatchesTarget =
    pkg:
    effectiveTargetPlatform == null
    || (
      platformFieldMatches pkg.os effectiveTargetPlatform.os
      && platformFieldMatches pkg.cpu effectiveTargetPlatform.cpu
      && platformFieldMatches pkg.libc effectiveTargetPlatform.libc
    );

  fetchedPackages = lib.filter packageMatchesTarget packages;
  skippedPackages = lib.filter (pkg: !(packageMatchesTarget pkg)) packages;

  globMatches =
    pattern: value:
    (builtins.match "^${concatStringsSep ".*" (map lib.escapeRegex (splitString "*" pattern))}$" value)
    != null;

  overrideKeyForPackage =
    pkg:
    let
      wildcardKeys = lib.attrNames (
        lib.filterAttrs (pattern: _: pattern != pkg.id && globMatches pattern pkg.id) packageSourceOverrides
      );
      sortedWildcardKeys = lib.sort (
        a: b: stringLength a > stringLength b || (stringLength a == stringLength b && a < b)
      ) wildcardKeys;
    in
    if builtins.hasAttr pkg.id packageSourceOverrides then
      pkg.id
    else if sortedWildcardKeys == [ ] then
      null
    else
      head sortedWildcardKeys;

  overrideForPackage =
    pkg:
    let
      key = overrideKeyForPackage pkg;
    in
    if key == null then null else packageSourceOverrides.${key};

  overrideKeysById = listToAttrs (
    map (pkg: nameValuePair pkg.id (overrideKeyForPackage pkg)) fetchedPackages
  );

  pnpmInstallFlags =
    if effectiveTargetPlatform == null then
      [ ]
    else
      [
        "--config.force=false"
        "--os"
        effectiveTargetPlatform.os
        "--cpu"
        effectiveTargetPlatform.cpu
      ]
      ++ lib.optionals (effectiveTargetPlatform.libc != null) [
        "--libc"
        effectiveTargetPlatform.libc
      ];

  patchedDependencies = lockfile.patchedDependencies or { };
  patchedDependencyFiles = lib.mapAttrs (
    id: _:
    patchedDependencySources.${id} or (throw ''
      importPnpmLock: patched dependency `${id}` has no patch source.
      Provide `patchedDependencySources.${id}` with the patch file from the
      workspace that produced the lockfile.
    '')
  ) patchedDependencies;
  patchedDependencyYaml = lib.mapAttrs (id: _: "patches/${id}.patch") patchedDependencies;

  packTarball =
    pkg: checkout:
    runCommand "${pkg.baseName}-${pkg.version}.tgz"
      {
        src = checkout;
      }
      ''
        tar \
          --sort=name \
          --mtime="@1" \
          --owner=0 \
          --group=0 \
          --numeric-owner \
          --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
          -czf "$out" \
          -C "$src" .
      '';

  patchPackageSource =
    {
      pkg,
      source,
      symlinks ? { },
    }:
    runCommand "${lib.strings.sanitizeDerivationName "${pkg.baseName}-${pkg.version}-patched"}"
      { src = source; }
      ''
        workDir="$TMPDIR/package-source"
        mkdir -p "$workDir"
        tar -xzf "$src" -C "$workDir"

        packageDir="$workDir/package"
        [ -d "$packageDir" ] || packageDir="$workDir"

        ${concatStringsSep "\n" (
          mapAttrsToList (path: target: ''
            matched=0
            for destination in "$packageDir"/${path}; do
              if [ -e "$destination" ] || [ -L "$destination" ]; then
                matched=1
                rm -f "$destination"
                mkdir -p "$(dirname "$destination")"
                ln -s ${lib.escapeShellArg target} "$destination"
              fi
            done
            [ "$matched" -eq 1 ] || {
              printf 'importPnpmLock: source path not found: %s\n' ${lib.escapeShellArg path} >&2
              exit 1
            }
          '') symlinks
        )}

        tar \
          --sort=name \
          --mtime="@1" \
          --owner=0 \
          --group=0 \
          --numeric-owner \
          --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
          -czf "$out" \
          -C "$workDir" .
      '';

  fetchGitSource =
    pkg:
    fetchgit (
      {
        url = pkg.gitUrl;
        rev = pkg.gitRev;
        hash =
          gitHashes.${pkg.id} or (throw ''
            importPnpmLock: git dependency `${pkg.id}` has no content hash.
            Provide `gitHashes.${pkg.id}` (an SRI hash, e.g. from
            `nix-prefetch-git`) or a `packageSourceOverrides.${pkg.id}`
            checkout.
          '');
      }
      // (fetcherOpts.${pkg.id} or { })
    );

  fetchRegistrySource =
    pkg:
    if pkg.integrity != "" then
      fetchurl (
        {
          url = pkg.url;
          hash = pkg.integrity;
        }
        // (fetcherOpts.${pkg.id} or { })
      )
    else
      throw ''
        importPnpmLock: tarball dependency `${pkg.id}` has no integrity
        hash in the lockfile. Provide `packageSourceOverrides.${pkg.id}`
        with a verified tarball (e.g. a fetchurl result) for this package.
      '';

  fetchDefaultSource =
    pkg:
    if pkg.kind == "git" then
      fetchGitSource pkg
    else if pkg.kind == "registry" || pkg.kind == "tarball" then
      fetchRegistrySource pkg
    else
      throw "importPnpmLock: unsupported package kind `${pkg.kind}` for `${pkg.id}`";

  fetchSource =
    pkg:
    let
      override = overrideForPackage pkg;
      previousSource = fetchDefaultSource pkg;
      source =
        if override == null then
          previousSource
        else if lib.isFunction override then
          override {
            inherit
              pkg
              previousSource
              patchPackageSource
              ;
          }
        else
          override;
    in
    if pkg.kind == "git" then packTarball pkg source else source;

  sourcesById = listToAttrs (map (pkg: nameValuePair pkg.id (fetchSource pkg)) fetchedPackages);
  kindById = listToAttrs (map (pkg: nameValuePair pkg.id pkg.kind) fetchedPackages);

  rewritePackage =
    id: v:
    if builtins.hasAttr id sourcesById then
      let
        src = sourcesById.${id};
        kind = kindById.${id};
        overrideKey = overrideKeysById.${id} or null;
        baseResolution = v.resolution or { };
      in
      v
      // {
        resolution =
          # Git sources are re-packed from a fetchgit checkout, so the lockfile's
          # original resolution does not describe the local tarball. A source
          # override may also change the tarball, so its original integrity is
          # not valid for the rewritten file URL.
          (
            if kind == "git" || overrideKey != null then
              builtins.removeAttrs baseResolution [ "integrity" ]
            else
              baseResolution
          )
          // {
            tarball = "file:${src}";
          };
      }
    else
      v;

  importerDeps =
    importer:
    let
      specifiers = type: lib.mapAttrs (name: info: info.specifier) (importer.${type} or { });
    in
    lib.optionalAttrs (importer ? dependencies) { dependencies = specifiers "dependencies"; }
    // lib.optionalAttrs (importer ? devDependencies) {
      devDependencies = specifiers "devDependencies";
    }
    // lib.optionalAttrs (importer ? optionalDependencies) {
      optionalDependencies = specifiers "optionalDependencies";
    }
    // lib.optionalAttrs (importer ? peerDependencies) {
      peerDependencies = specifiers "peerDependencies";
    };

  importers = lib.mapAttrs (
    path: importer:
    importer
    // lib.optionalAttrs (builtins.hasAttr path importerDependencyOverrides) {
      dependencies = (importer.dependencies or { }) // importerDependencyOverrides.${path};
    }
  ) (lockfile.importers or { });

  rewrittenLockfileData = lockfile // {
    inherit importers;
    packages = lib.mapAttrs rewritePackage (lockfile.packages or { });
  };

  lockfileYaml = writeText "pnpm-lock.yaml" (builtins.toJSON rewrittenLockfileData);

  workspacePaths = lib.filter (path: path != ".") (lib.attrNames importers);

  rootPackageJson = writeText "package.json" (
    builtins.toJSON (
      {
        name = effectivePname;
        version = "0.0.0";
      }
      // importerDeps (importers."." or { })
    )
  );

  workspacePackageJson =
    path:
    writeText "pnpm-workspace-${lib.strings.sanitizeDerivationName path}.json" (
      builtins.toJSON (
        {
          name = lib.last (lib.splitString "/" path);
          version = "0.0.0";
        }
        // importerDeps importers.${path}
      )
    );

  workspaceFileInputs = lib.listToAttrs (
    map (path: nameValuePair "${path}/package.json" (workspacePackageJson path)) workspacePaths
  );
  workspaceConfig = {
    packages = workspacePaths;
  }
  // lib.optionalAttrs (lockfile ? settings) lockfile.settings
  // lib.optionalAttrs (lockfile ? overrides) { overrides = lockfile.overrides; }
  // lib.optionalAttrs (patchedDependencies != { }) {
    patchedDependencies = patchedDependencyYaml;
  };
  workspaceYaml =
    if
      workspacePaths == [ ]
      && !(lockfile ? settings)
      && !(lockfile ? overrides)
      && patchedDependencies == { }
    then
      null
    else
      writeText "pnpm-workspace.yaml" (builtins.toJSON workspaceConfig);

  source =
    runCommand "pnpm-deps-source"
      {
        inherit rootPackageJson lockfileYaml;
        workspaceYaml = workspaceYaml;
      }
      ''
        mkdir -p $out
        cp $rootPackageJson $out/package.json
        cp $lockfileYaml $out/pnpm-lock.yaml
        ${lib.optionalString (workspaceYaml != null) "cp $workspaceYaml $out/pnpm-workspace.yaml"}
        ${concatStringsSep "\n" (
          mapAttrsToList (name: input: "install -Dm444 ${input} \"$out/${name}\"") workspaceFileInputs
        )}
        ${concatStringsSep "\n" (
          mapAttrsToList (
            name: input: "install -Dm444 \"${input}\" \"$out/patches/${name}.patch\""
          ) patchedDependencyFiles
        )}
      '';

  upstream = fetchPnpmDeps {
    pname = effectivePname;
    pnpm = pnpmPkg;
    fetcherVersion = effectiveFetcherVersion;
    src = source;
    hash = "";
    inherit pnpmInstallFlags;
  };
  nativeBuildInputs' = upstream.nativeBuildInputs;
in
assert elem effectiveFetcherVersion [
  3
  4
];

lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;

  extendDrvArgs =
    finalAttrs:
    {
      pname ? effectivePname,
      version ? "pnpm-deps",
      ...
    }:
    {
      inherit pname version;
      name = "${finalAttrs.pname}-${finalAttrs.version}";

      inherit (upstream) installPhase fixupPhase;
      nativeBuildInputs = nativeBuildInputs';

      src = source;
      dontConfigure = true;
      dontBuild = true;

      preInstall = ''
        export PNPM_CONFIG_TRUST_LOCKFILE=true
        export pnpm_config_trust_lockfile=true
        export NIX_NPM_REGISTRY="${registry}"
      '';

      passthru = {
        inherit
          packages
          fetchedPackages
          skippedPackages
          pnpmInstallFlags
          ;
        fetchPnpmDeps = upstream;
        targetPlatform = effectiveTargetPlatform;
        fetcherVersion = effectiveFetcherVersion;
      };
    };
} { }
