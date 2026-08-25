{
  baseBundle,
  coreutils,
  diffutils,
  gnugrep,
  dshBundleResolver,
  dsh-kernel,
  agentPresets,
  lib,
  linkFarm,
  runCommand,
  util-linux,
  writeShellApplication,
  writeText,
  tuiBundle,
  webBundle,
  yq-go,
}:

let
  profilePrefix = "nix-";
  presetIdPattern = "^[a-z0-9][a-z0-9-]*$";
  managedFiles = [
    "package.json"
    "cordis.patch.yml"
    "pnpm-workspace.yaml"
  ];

  profileName = name: "${profilePrefix}${name}";

  validatePresetId =
    label: id:
    if !lib.isString id || builtins.match presetIdPattern id == null then
      throw "dsh profile: ${label} must match ${presetIdPattern}"
    else
      id;

  validatePresetDefinition =
    id: definition:
    let
      source = validatePresetId "agentPresets.${id}.source" (definition.source or "standard");
      enableTools = definition.enableTools or [ ];
      name = definition.name or null;
      description = definition.description or null;
    in
    if !lib.isList enableTools || !lib.all lib.isString enableTools then
      throw "dsh profile: agentPresets.${id}.enableTools must be a list of strings"
    else if name != null && !lib.isString name then
      throw "dsh profile: agentPresets.${id}.name must be null or a string"
    else if description != null && !lib.isString description then
      throw "dsh profile: agentPresets.${id}.description must be null or a string"
    else
      {
        inherit
          description
          enableTools
          name
          source
          ;
      };

  presetDefinitions = lib.mapAttrs (
    id: definition: validatePresetDefinition (validatePresetId "agentPresets id" id) definition
  ) agentPresets;

  profileAgentPreset =
    name: profile:
    let
      configured = profile.agentPreset or null;
    in
    if configured == null then
      null
    else
      let
        id = validatePresetId "profiles.${name}.agentPreset" configured;
      in
      if !builtins.hasAttr id presetDefinitions then
        throw "dsh profile: profiles.${name}.agentPreset references undeclared agentPresets.${id}"
      else
        {
          inherit id;
          definition = builtins.getAttr id presetDefinitions;
        };

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
    || (profile.agentPreset or null) != null
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

  makeAgentPresetTemplate =
    id: definition:
    let
      sourceDir = "${dsh-kernel}/lib/deepseek-harness/config/agent-presets/${definition.source}";
      shippedRoot = "${dsh-kernel}/lib/deepseek-harness/config/agent-presets";
      emptyMetadata = writeText "dsh-agent-preset-empty.yml" "{}\n";
      marker = writeText "dsh-agent-preset-${id}-managed" ''
        owner=nix
        schema=1
        preset=${id}
      '';
      presetMetadata = ''
        yq -i 'del(.name, .order)' "$out/preset.yml"
      ''
      + lib.optionalString (definition.name != null) ''
        PRESET_NAME=${lib.escapeShellArg definition.name} \
          yq -i '.name = strenv(PRESET_NAME)' "$out/preset.yml"
      ''
      + lib.optionalString (definition.description != null) ''
        PRESET_DESCRIPTION=${lib.escapeShellArg definition.description} \
          yq -i '.description = strenv(PRESET_DESCRIPTION)' "$out/preset.yml"
      ''
      + lib.concatMapStringsSep "\n" (row: ''
        rowCount=$(DSH_PRESET_ROW=${lib.escapeShellArg row} yq -r '[.. | select(type == "!!map") | select(.id == strenv(DSH_PRESET_ROW))] | length' "$out/agent.cordis.yml")
        [ "$rowCount" -eq 1 ] || {
          printf 'dsh profile: Agent Preset row must occur exactly once: %s (found %s)\n' ${lib.escapeShellArg row} "$rowCount" >&2
          exit 1
        }
        DSH_PRESET_ROW=${lib.escapeShellArg row} yq -i \
          'del(.. | select(type == "!!map") | select(.id == strenv(DSH_PRESET_ROW)) | .disabled)' \
          "$out/agent.cordis.yml"
      '') definition.enableTools;
    in
    runCommand (lib.strings.sanitizeDerivationName "dsh-agent-preset-${id}")
      {
        nativeBuildInputs = [ yq-go ];
      }
      ''
        mkdir -p "$out"
        [ -d ${lib.escapeShellArg sourceDir} ] || {
          printf 'dsh profile: shipped Agent Preset is missing: %s\n' ${lib.escapeShellArg definition.source} >&2
          exit 1
        }
        [ ! -d ${lib.escapeShellArg "${shippedRoot}/${id}"} ] || {
          printf 'dsh profile: user Agent Preset shadows a shipped preset: %s\n' ${lib.escapeShellArg id} >&2
          exit 1
        }
        cp -r ${lib.escapeShellArg sourceDir}/. "$out/"
        chmod -R u+w "$out"
        [ -f "$out/agent.cordis.yml" ] || {
          printf 'dsh profile: shipped Agent Preset has no agent.cordis.yml: %s\n' ${lib.escapeShellArg definition.source} >&2
          exit 1
        }
        if [ ! -f "$out/preset.yml" ]; then
          cp ${lib.escapeShellArg emptyMetadata} "$out/preset.yml"
        fi
        ${presetMetadata}
        cp ${lib.escapeShellArg marker} "$out/.nix-managed"
      '';

  profileSpec =
    name: profile:
    let
      targetName = profileName name;
      mode = validateMode (profile.mode or "managed");
      agentPreset = profileAgentPreset name profile;
      # The manifest argument order is the Cordis patch order. Keep the base
      # layer first, then apply profile bundles in their declared order.
      bundleManifests = map (bundle: "${bundle}/nix-support/dsh-bundles.json") (
        [ baseBundle ] ++ profileBundles profile
      );
      rawPatch = profile.patch or [ ];
      agentPresetPatch =
        if agentPreset == null then
          [ ]
        else
          [
            {
              id = "agent-presets";
              config.default = agentPreset.id;
            }
          ];
      patch =
        if agentPreset == null then
          renderPatch rawPatch
        else if lib.isList rawPatch then
          renderPatch (rawPatch ++ agentPresetPatch)
        else
          rawPatch;
      patchFile =
        if agentPreset == null || lib.isList rawPatch then
          writeText "dsh-profile-${targetName}-cordis.patch.yml" patch
        else
          let
            basePatchFile = writeText "dsh-profile-${targetName}-raw-cordis.patch.yml" rawPatch;
            agentPatchFile = writeText "dsh-profile-${targetName}-agent-preset.patch.yml" (
              renderPatch agentPresetPatch
            );
          in
          runCommand "dsh-profile-${targetName}-cordis.patch.yml" { nativeBuildInputs = [ yq-go ]; } ''
            cp ${lib.escapeShellArg basePatchFile} "$out"
            chmod u+w "$out"
            DSH_AGENT_PRESET_PATCH=${lib.escapeShellArg agentPatchFile} \
              yq -i '. += load(strenv(DSH_AGENT_PRESET_PATCH))' "$out"
          '';
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
          inherit agentPreset;
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
        agentPreset
        marker
        packageJson
        patch
        patchFile
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
          "${spec.targetName}/cordis.patch.yml" = spec.patchFile;
          "${spec.targetName}/pnpm-workspace.yaml" =
            writeText "${lib.strings.sanitizeDerivationName "dsh-profile-${spec.targetName}-pnpm-workspace.yaml"}" "${spec.workspace}\n";
          "${spec.targetName}/.nix-managed" =
            writeText "${lib.strings.sanitizeDerivationName "dsh-profile-${spec.targetName}-managed"}" spec.marker;
        }
      ) profiles
    );

  makeAgentPresetTemplates =
    { }:
    linkFarm "deepseek-harness-agent-presets" (
      lib.mapAttrsToList (id: definition: {
        name = id;
        path = makeAgentPresetTemplate id definition;
      }) presetDefinitions
    );

  makeProfileSeeder =
    {
      agentPresetTemplates,
      homePatchFile ? null,
      profileTemplates,
      profiles,
    }:
    let
      seedInvocation =
        name: profile:
        let
          spec = profileSpec name profile;
          targetName = profileName name;
          mode = validateMode (profile.mode or "managed");
          seeder = if mode == "managed" then "sync_managed_profile" else "seed_mutable_profile";
          agentPresetSeeder =
            if mode == "managed" then "sync_managed_agent_preset" else "seed_mutable_agent_preset";
          agentPresetInvocation =
            if spec.agentPreset == null then
              ""
            else
              ''
                ${agentPresetSeeder} ${lib.escapeShellArg spec.agentPreset.id} ${lib.escapeShellArg "${agentPresetTemplates}/${spec.agentPreset.id}"} "$home/.agent-presets/${spec.agentPreset.id}"
              '';
        in
        ''
          ${seeder} ${lib.escapeShellArg targetName} ${lib.escapeShellArg "${profileTemplates}/${targetName}"} "$home/profiles/${targetName}"
          ${agentPresetInvocation}
        '';
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
        mkdir -p "$home/.agent-presets"
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

        validate_agent_preset_dir() {
          local preset=$1
          local destination=$2

          [ ! -L "$destination" ] || die "refusing to follow Agent Preset symlink: $destination"

          if [ -e "$destination" ]; then
            [ -d "$destination" ] || die "Agent Preset path is not a directory: $destination"
            validate_owned_file "$destination/.nix-managed"
            [ -f "$destination/.nix-managed" ] || die "refusing to take over existing unmanaged Agent Preset '$preset' at $destination"
            grep -Fxq 'owner=nix' "$destination/.nix-managed" \
              || die "Agent Preset marker has an unexpected owner: $destination/.nix-managed"
            grep -Fxq "preset=$preset" "$destination/.nix-managed" \
              || die "Agent Preset marker belongs to another preset: $destination/.nix-managed"
          fi
        }

        validate_agent_preset_source() {
          local source=$1

          [ -d "$source" ] || die "managed Agent Preset source is missing: $source"
          [ -f "$source/agent.cordis.yml" ] || die "managed Agent Preset composition is missing: $source/agent.cordis.yml"
          [ -f "$source/.nix-managed" ] || die "managed Agent Preset marker is missing: $source/.nix-managed"
        }

        replace_agent_preset_tree() {
          local source=$1
          local destination=$2
          local expected_identity=''${3:-}
          local destination_mode current_identity temporary

          if [ -n "$expected_identity" ]; then
            destination_mode=$(stat --format='%a' -- "$destination") \
              || die "failed to inspect managed Agent Preset: $destination"
          else
            destination_mode=$(stat --format='%a' -- "$(dirname "$destination")") \
              || die "failed to inspect Agent Preset parent: $destination"
          fi

          # Stage beside the destination so a managed tree is replaced as one unit.
          temporary=$(mktemp -d "$(dirname "$destination")/.''${destination##*/}.tmp.XXXXXX")
          if ! cp -r --dereference --no-preserve=mode "$source"/. "$temporary"/; then
            rm -rf --one-file-system -- "$temporary"
            die "failed to stage managed Agent Preset: $source"
          fi
          if ! chmod "$destination_mode" "$temporary"; then
            rm -rf --one-file-system -- "$temporary"
            die "failed to set managed Agent Preset mode: $destination"
          fi

          if [ -n "$expected_identity" ]; then
            current_identity=$(stat --format='%d:%i' -- "$destination") || {
              rm -rf --one-file-system -- "$temporary"
              die "managed Agent Preset disappeared during sync: $destination"
            }
            if [ "$current_identity" != "$expected_identity" ]; then
              rm -rf --one-file-system -- "$temporary"
              die "managed Agent Preset changed during sync: $destination"
            fi
            if ! mv --exchange --no-copy -T -- "$temporary" "$destination"; then
              rm -rf --one-file-system -- "$temporary"
              die "failed to atomically replace managed Agent Preset: $destination"
            fi
            rm -rf --one-file-system -- "$temporary" \
              || die "failed to remove previous managed Agent Preset: $temporary"
          else
            if [ -e "$destination" ] || [ -L "$destination" ]; then
              rm -rf --one-file-system -- "$temporary"
              die "Agent Preset appeared during sync: $destination"
            fi
            if ! mv --no-copy --update=none-fail -T -- "$temporary" "$destination"; then
              rm -rf --one-file-system -- "$temporary"
              die "failed to install managed Agent Preset: $destination"
            fi
          fi
        }

        sync_managed_agent_preset() {
          local preset=$1
          local source=$2
          local destination=$3
          local destination_identity=

          validate_agent_preset_source "$source"
          validate_agent_preset_dir "$preset" "$destination"
          if [ -e "$destination" ]; then
            destination_identity=$(stat --format='%d:%i' -- "$destination") \
              || die "failed to inspect managed Agent Preset: $destination"
          fi
          replace_agent_preset_tree "$source" "$destination" "$destination_identity"
        }

        seed_mutable_agent_preset() {
          local preset=$1
          local source=$2
          local destination=$3

          validate_agent_preset_source "$source"
          if [ -e "$destination" ] || [ -L "$destination" ]; then
            validate_agent_preset_dir "$preset" "$destination"
            return 0
          fi

          replace_agent_preset_tree "$source" "$destination"
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
