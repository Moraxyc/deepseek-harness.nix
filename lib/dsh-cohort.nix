# Access to the tarball set upstream emits with `release:pack --family dsh`.
#
# The cohort is a build output, so its member list cannot be read at evaluation
# time without IFD. The members this repository consumes are declared here once,
# bundles only select from that list, and the build-time assertions catch a
# renamed member or a version that drifted from the workspace.
{
  lib,
  copyTree,
  dsh-workspace,
  jq,
  stdenvNoCC,
}:

let
  scope = "@deepseek-ai";

  # Published client packages a bundle compiles against, by unscoped name. A
  # tarball is the npm consumer view: the export map, file list, and dependency
  # versions a plugin resolves, which the kernel runtime closure does not carry.
  members = [
    "dsh-api-remotes"
    "dsh-api-session-controller"
    "dsh-api-workspace-controller"
    "dsh-client-connection"
    "dsh-client-locale"
    "dsh-client-store"
    "dsh-client-ui-commands"
    "dsh-client-ui-conversation"
    "dsh-client-ui-input-trigger"
    "dsh-client-ui-primitives"
    "dsh-client-ui-renderer"
    "dsh-client-ui-session"
    "dsh-client-ui-settings"
    "dsh-client-ui-slots"
    "dsh-client-ui-workspace"
  ];

  # Members are declared by unscoped name; callers may pass either form.
  bareName = name: lib.removePrefix "${scope}/" name;
  scopedName = name: "${scope}/${bareName name}";
  declare =
    name:
    lib.assertMsg (lib.elem (bareName name) members) "dshCohort: ${name} is not declared in lib/dsh-cohort.nix";

  # Upstream packs a member as `<unscoped scope>-<unscoped name>-<version>.tgz`.
  tarballBase = name: "${lib.removePrefix "@" scope}-${bareName name}";
  tarballName = name: "${tarballBase name}-${dsh-workspace.version}.tgz";

  # A bundle names the peers it compiles against; the result carries the scope
  # that node_modules paths and removal loops need. An undeclared name fails
  # evaluation rather than the build.
  select =
    names:
    assert lib.all declare names;
    map scopedName names;

  member =
    name:
    assert declare name;
    stdenvNoCC.mkDerivation {
      pname = tarballBase name;
      version = dsh-workspace.version;
      src = "${dsh-workspace.cohort}/${tarballName name}";

      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      nativeBuildInputs = [ jq ];
      disallowedReferences = [ jq ];

      installPhase = ''
        runHook preInstall

        mkdir -p "$out"
        tar -xzf "$src" -C "$out" --strip-components=1

        packedName=$(jq -r '.name' "$out/package.json")
        packedVersion=$(jq -r '.version' "$out/package.json")
        [ "$packedName" = ${lib.escapeShellArg (scopedName name)} ] || {
          printf 'dshCohort: cohort member is %s, expected %s\n' \
            "$packedName" ${lib.escapeShellArg (scopedName name)} >&2
          exit 1
        }
        [ "$packedVersion" = ${lib.escapeShellArg dsh-workspace.version} ] || {
          printf 'dshCohort: cohort member version is %s, expected %s\n' \
            "$packedVersion" ${lib.escapeShellArg dsh-workspace.version} >&2
          exit 1
        }

        runHook postInstall
      '';

      meta = {
        description = "Published cohort member ${scopedName name} of DeepSeek Harness";
        platforms = lib.platforms.unix;
      };
    };

  # Replaces any workspace copy of the named members and copies the published
  # package in, so the consumer-facing files are the ones that end up compiled.
  installPackages =
    {
      dest ? "node_modules",
      names,
    }:
    lib.concatMapStringsSep "\n" (
      name:
      let
        target = "${dest}/${scopedName name}";
      in
      ''
        rm -rf "${target}"
        ${copyTree.followLinks {
          src = member name;
          dest = target;
        }}
      ''
    ) names;

  # A missing or renamed member is a release-tooling change rather than a bundle
  # bug, so report it as its own check instead of as a `tar` failure in a bundle.
  check = stdenvNoCC.mkDerivation {
    pname = "dsh-cohort-check";
    version = dsh-workspace.version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cohort="${dsh-workspace.cohort}"
      order="$cohort/publish-order.txt"
      [ -f "$order" ] || {
        printf 'dshCohort: %s carries no publish-order.txt\n' "$cohort" >&2
        exit 1
      }

      inOrder() {
        local entry
        while IFS= read -r entry; do
          [ "$entry" = "$1" ] && return 0
        done < "$order"
        return 1
      }

      failed=0
      for tarball in ${lib.escapeShellArgs (map tarballName members)}; do
        if [ ! -f "$cohort/$tarball" ]; then
          printf 'dshCohort: declared member is missing from the cohort: %s\n' "$tarball" >&2
          failed=1
        fi
        if ! inOrder "$tarball"; then
          printf 'dshCohort: declared member is absent from the publish order: %s\n' "$tarball" >&2
          failed=1
        fi
      done
      [ "$failed" = 0 ] || exit 1

      touch "$out/checked"
      runHook postInstall
    '';

    meta = {
      description = "Check that every declared cohort member is present in the DSH release pack";
      platforms = lib.platforms.unix;
    };
  };
in
{
  inherit
    check
    installPackages
    member
    select
    ;
}
