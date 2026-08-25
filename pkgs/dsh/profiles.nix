{
  baseBundle,
  coreutils,
  diffutils,
  gnugrep,
  dshBundleResolver,
  lib,
  linkFarm,
  runCommand,
  util-linux,
  writeShellApplication,
  writeText,
  tuiBundle,
  webBundle,
}:

let
  profilePrefix = "nix-";
  managedFiles = [
    "package.json"
    "cordis.patch.yml"
    "pnpm-workspace.yaml"
  ];

  profileName = name: "${profilePrefix}${name}";

  validateMode =
    mode:
    if mode == "managed" || mode == "mutable" then
      mode
    else
      throw "dsh profile: invalid mode '${mode}', expected 'managed' or 'mutable'";

  renderPatch =
    patch:
    if lib.isString patch then
      patch
    else if lib.isList patch then
      lib.generators.toYAML { } patch
    else
      throw "dsh profile: patch must be a YAML string or a list of patch operations";

  profileNeedsWeb =
    profile:
    (profile.requiresWeb or false)
    || lib.any (bundle: bundle.passthru.requiresWeb or false) (profile.bundles or [ ]);

  profileNeedsTui =
    profile:
    (profile.requiresTui or false)
    || lib.any (bundle: bundle.passthru.requiresTui or false) (profile.bundles or [ ]);

  profileBundles =
    profile:
    lib.unique (
      lib.optional (profileNeedsWeb profile) webBundle
      ++ lib.optional (profileNeedsTui profile) tuiBundle
      ++ (profile.bundles or [ ])
    );

  profileSpec =
    name: profile:
    let
      targetName = profileName name;
      mode = validateMode (profile.mode or "managed");
      # The manifest argument order is the Cordis patch order. Keep the base
      # layer first, then apply profile bundles in their declared order.
      bundleManifests = map (bundle: "${bundle}/nix-support/dsh-bundles.json") (
        [ baseBundle ] ++ profileBundles profile
      );
      patch = renderPatch (profile.patch or "[]");
      packageJson = runCommand "dsh-profile-${targetName}-package.json" { } ''
        mkdir -p "$out"
        ${lib.getExe dshBundleResolver} profile "$out/package.json" \
          ${lib.escapeShellArg targetName} \
          ${lib.concatStringsSep " " (map lib.escapeShellArg bundleManifests)}
      '';
      workspace = builtins.toJSON {
        packages = [ "." ];
        nodeLinker = "hoisted";
        autoInstallPeers = false;
      };
      fingerprint = builtins.hashString "sha256" (
        builtins.toJSON {
          inherit
            bundleManifests
            mode
            patch
            targetName
            ;
        }
      );
      marker = ''
        owner=nix
        schema=1
        profile=${targetName}
        fingerprint=${fingerprint}
      '';
    in
    {
      inherit
        marker
        packageJson
        patch
        targetName
        workspace
        ;
    };
in
{
  inherit
    profileBundles
    profileNeedsTui
    profileName
    profileNeedsWeb
    renderPatch
    ;

  makeProfileTemplates =
    { profiles }:
    linkFarm "deepseek-harness-profiles" (
      lib.concatMapAttrs (
        name: profile:
        let
          spec = profileSpec name profile;
        in
        {
          "${spec.targetName}/package.json" = "${spec.packageJson}/package.json";
          "${spec.targetName}/cordis.patch.yml" =
            writeText "${lib.strings.sanitizeDerivationName "dsh-profile-${spec.targetName}-cordis.patch.yml"}" spec.patch;
          "${spec.targetName}/pnpm-workspace.yaml" =
            writeText "${lib.strings.sanitizeDerivationName "dsh-profile-${spec.targetName}-pnpm-workspace.yaml"}" "${spec.workspace}\n";
          "${spec.targetName}/.nix-managed" =
            writeText "${lib.strings.sanitizeDerivationName "dsh-profile-${spec.targetName}-managed"}" spec.marker;
        }
      ) profiles
    );

  makeProfileSeeder =
    {
      homePatchFile ? null,
      profileTemplates,
      profiles,
    }:
    let
      seedInvocation =
        name: profile:
        let
          targetName = profileName name;
          mode = validateMode (profile.mode or "managed");
          seeder = if mode == "managed" then "sync_managed_profile" else "seed_mutable_profile";
        in
        "${seeder} ${lib.escapeShellArg targetName} ${lib.escapeShellArg "${profileTemplates}/${targetName}"} \"$home/profiles/${targetName}\"";
    in
    writeShellApplication {
      name = "dsh-sync-profiles";
      runtimeInputs = [
        coreutils
        diffutils
        gnugrep
        util-linux
      ];
      inheritPath = false;
      text = ''
        home=''${DSH_HOME:-''${HOME:+$HOME/.dsh}}
        [ -n "$home" ] || exit 0

        mkdir -p "$home/profiles"
        exec 9>"$home/profiles/.nix-sync.lock"
        flock 9

        die() {
          printf 'dsh: %s\n' "$1" >&2
          exit 1
        }

        validate_owned_file() {
          local destination=$1

          [ ! -L "$destination" ] || die "refusing to overwrite symlink: $destination"
          if [ -e "$destination" ] && [ ! -f "$destination" ]; then
            die "refusing to overwrite non-file: $destination"
          fi
        }

        copy_owned_file() {
          local source=$1
          local destination=$2
          local temporary

          [ -f "$source" ] || die "managed source is missing: $source"
          validate_owned_file "$destination"

          if [ -f "$destination" ] && cmp -s "$source" "$destination"; then
            return 0
          fi

          temporary=$(mktemp "$destination.tmp.XXXXXX")
          cp --dereference --no-preserve=mode "$source" "$temporary"
          mv -f "$temporary" "$destination"
        }

        validate_profile_dir() {
          local profile=$1
          local destination=$2

          [ ! -L "$destination" ] || die "refusing to follow profile symlink: $destination"

          if [ -e "$destination" ]; then
            [ -d "$destination" ] || die "profile path is not a directory: $destination"
            [ -f "$destination/.nix-managed" ] || die "refusing to take over existing unmanaged profile '$profile' at $destination"
            grep -Fxq 'owner=nix' "$destination/.nix-managed" \
              || die "managed marker has an unexpected owner: $destination/.nix-managed"
            grep -Fxq "profile=$profile" "$destination/.nix-managed" \
              || die "managed marker belongs to another profile: $destination/.nix-managed"
          else
            mkdir "$destination"
          fi
        }

        sync_managed_profile() {
          local profile=$1
          local source=$2
          local destination=$3

          [ -d "$source" ] || die "managed profile source is missing: $source"
          validate_profile_dir "$profile" "$destination"

          ${lib.concatStringsSep "\n" (
            map (file: "  validate_owned_file \"$destination/${file}\"") managedFiles
          )}
          validate_owned_file "$destination/.nix-managed"

          ${lib.concatStringsSep "\n" (
            map (file: "  copy_owned_file \"$source/${file}\" \"$destination/${file}\"") managedFiles
          )}
          copy_owned_file "$source/.nix-managed" "$destination/.nix-managed"
        }

        seed_mutable_profile() {
          local profile=$1
          local source=$2
          local destination=$3

          [ -d "$source" ] || die "managed profile source is missing: $source"

          if [ -e "$destination" ]; then
            validate_profile_dir "$profile" "$destination"
            return 0
          fi

          mkdir "$destination"

          ${lib.concatStringsSep "\n" (
            map (file: "  copy_owned_file \"$source/${file}\" \"$destination/${file}\"") managedFiles
          )}
          copy_owned_file "$source/.nix-managed" "$destination/.nix-managed"
        }

        requested_profile=''${1:-}
        ${lib.optionalString (homePatchFile != null) ''
          copy_owned_file ${lib.escapeShellArg "${homePatchFile}"} "$home/cordis.patch.yml"
        ''}
        case "$requested_profile" in
          "")
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList seedInvocation profiles)}
            ;;
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: profile: "${lib.escapeShellArg (profileName name)}) ${seedInvocation name profile} ;;"
            ) profiles
          )}
          *)
            ;;
        esac
      '';
    };
}
