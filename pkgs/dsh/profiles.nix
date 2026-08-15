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
}:

let
  profilePrefix = "nix-";
  managedFiles = [
    "package.json"
    "cordis.patch.yml"
    "pnpm-workspace.yaml"
  ];

  profileName = name: "${profilePrefix}${name}";

  profileSpec =
    name: profile:
    let
      targetName = profileName name;
      bundleManifests = map (bundle: "${bundle}/nix-support/dsh-bundles.json") (
        lib.unique ([ baseBundle ] ++ profile.bundles)
      );
      patch = profile.patch or "[]";
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
  inherit profileName;

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
      profileTemplates,
      profiles,
    }:
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

          [ -f "$source" ] || die "managed profile source is missing: $source"
          validate_owned_file "$destination"

          if [ -f "$destination" ] && cmp -s "$source" "$destination"; then
            return 0
          fi

          temporary=$(mktemp "$destination.tmp.XXXXXX")
          cp --dereference --no-preserve=mode "$source" "$temporary"
          mv -f "$temporary" "$destination"
        }

        sync_profile() {
          local profile=$1
          local source=$2
          local destination=$3

          [ -d "$source" ] || die "managed profile source is missing: $source"
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

          ${lib.concatStringsSep "\n" (
            map (file: "  validate_owned_file \"$destination/${file}\"") managedFiles
          )}
          validate_owned_file "$destination/.nix-managed"

          ${lib.concatStringsSep "\n" (
            map (file: "  copy_owned_file \"$source/${file}\" \"$destination/${file}\"") managedFiles
          )}
          copy_owned_file "$source/.nix-managed" "$destination/.nix-managed"
        }

        requested_profile=''${1:-}
        case "$requested_profile" in
          "")
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: _profile:
                let
                  targetName = profileName name;
                in
                "sync_profile ${lib.escapeShellArg targetName} ${lib.escapeShellArg "${profileTemplates}/${targetName}"} \"$home/profiles/${targetName}\""
              ) profiles
            )}
            ;;
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: _profile:
              let
                targetName = profileName name;
              in
              "${lib.escapeShellArg targetName}) sync_profile ${lib.escapeShellArg targetName} ${lib.escapeShellArg "${profileTemplates}/${targetName}"} \"$home/profiles/${targetName}\" ;;"
            ) profiles
          )}
          *)
            ;;
        esac
      '';
    };
}
