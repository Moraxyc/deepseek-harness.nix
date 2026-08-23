{
  baseBundle,
  coreutils,
  diffutils,
  gnugrep,
  dshBundleResolver,
  dsh-kernel,
  lib,
  linkFarm,
  runCommand,
  util-linux,
  writeShellApplication,
  writeText,
  webBundle,
  yq-go,
}:

let
  profilePrefix = "nix-";
  presetIdPattern = "^[a-z0-9][a-z0-9-]*$";
  shippedAgentPresetIds = [
    "code"
    "cordis"
    "minimal"
    "standard"
  ];
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

  validateUserPresetId =
    label: id:
    let
      validId = validatePresetId label id;
    in
    if lib.elem validId shippedAgentPresetIds then
      throw "dsh profile: ${label} must not shadow a shipped Agent Preset: ${validId}"
    else
      validId;

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

  makeAgentPresetTemplate =
    {
      targetName,
      preset,
    }:
    let
      id = validateUserPresetId "agentPreset.id" preset.id;
      source = validatePresetId "agentPreset.source" (preset.source or "standard");
      enableTools = preset.enableTools or [ ];
      sourceDir = "${dsh-kernel}/lib/deepseek-harness/config/agent-presets/${source}";
      emptyMetadata = writeText "dsh-agent-preset-empty.yml" "{}\n";
      marker = writeText "dsh-agent-preset-${id}-managed" ''
        owner=nix
        schema=1
        preset=${id}
      '';
    in
    assert lib.isList enableTools;
    runCommand (lib.strings.sanitizeDerivationName "dsh-agent-preset-${targetName}-${id}")
      {
        nativeBuildInputs = [ yq-go ];
      }
      ''
        mkdir -p "$out"
        [ -d ${lib.escapeShellArg sourceDir} ] || {
          printf 'dsh profile: shipped Agent Preset is missing: %s\n' ${lib.escapeShellArg source} >&2
          exit 1
        }
        cp -r ${lib.escapeShellArg sourceDir}/. "$out/"
        chmod -R u+w "$out"
        if [ ! -f "$out/preset.yml" ]; then
          cp ${lib.escapeShellArg emptyMetadata} "$out/preset.yml"
        fi
        yq -i 'del(.name, .order)' "$out/preset.yml"
        ${lib.optionalString ((preset.name or null) != null) (
          "PRESET_NAME="
          + lib.escapeShellArg preset.name
          + " yq -i '.name = strenv(PRESET_NAME)' \"$out/preset.yml\""
        )}
        ${lib.optionalString ((preset.description or null) != null) (
          "PRESET_DESCRIPTION="
          + lib.escapeShellArg preset.description
          + " yq -i '.description = strenv(PRESET_DESCRIPTION)' \"$out/preset.yml\""
        )}
        ${lib.concatMapStringsSep "\n" (
          row:
          assert lib.isString row;
          ''
            rowCount=$(DSH_PRESET_ROW=${lib.escapeShellArg row} yq -r '[.. | select(type == "!!map") | select(.id == strenv(DSH_PRESET_ROW))] | length' "$out/agent.cordis.yml")
            [ "$rowCount" -gt 0 ] || {
              printf 'dsh profile: Agent Preset row is missing: %s\n' ${lib.escapeShellArg row} >&2
              exit 1
            }
            DSH_PRESET_ROW=${lib.escapeShellArg row} yq -i \
              'del(.. | select(type == "!!map") | select(.id == strenv(DSH_PRESET_ROW)) | .disabled)' \
              "$out/agent.cordis.yml"
          ''
        ) enableTools}
        cp ${lib.escapeShellArg marker} "$out/.nix-managed"
      '';

  agentPresetPatch = preset: {
    id = "agent-presets";
    config.default = preset.id;
  };

  profileNeedsWeb =
    profile:
    (profile.requiresWeb or false)
    || (profile.agentPreset or null) != null
    || lib.any (bundle: bundle.passthru.requiresWeb or false) (profile.bundles or [ ]);

  profileBundles =
    profile: lib.unique (lib.optional (profileNeedsWeb profile) webBundle ++ (profile.bundles or [ ]));

  profileSpec =
    name: profile:
    let
      targetName = profileName name;
      mode = validateMode (profile.mode or "managed");
      configuredAgentPreset = profile.agentPreset or null;
      agentPreset =
        if configuredAgentPreset == null then
          null
        else
          let
            id = validateUserPresetId "agentPreset.id" configuredAgentPreset.id;
            source = validatePresetId "agentPreset.source" (configuredAgentPreset.source or "standard");
          in
          configuredAgentPreset
          // {
            inherit id source;
            template = makeAgentPresetTemplate {
              inherit targetName;
              preset = configuredAgentPreset // {
                inherit id source;
              };
            };
          };
      # The manifest argument order is the Cordis patch order. Keep the base
      # layer first, then apply profile bundles in their declared order.
      bundleManifests = map (bundle: "${bundle}/nix-support/dsh-bundles.json") (
        [ baseBundle ] ++ profileBundles profile
      );
      rawPatch = profile.patch or [ ];
      patch =
        if agentPreset == null then
          renderPatch rawPatch
        else if !lib.isList rawPatch then
          rawPatch
        else
          renderPatch (rawPatch ++ [ (agentPresetPatch agentPreset) ]);
      patchFile =
        if agentPreset == null || lib.isList rawPatch then
          writeText "dsh-profile-${targetName}-cordis.patch.yml" patch
        else
          let
            basePatchFile = writeText "dsh-profile-${targetName}-raw-cordis.patch.yml" patch;
            agentPatchFile = writeText "dsh-profile-${targetName}-agent-preset.patch.yml" (renderPatch [
              (agentPresetPatch agentPreset)
            ]);
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
          agentPreset =
            if agentPreset == null then
              null
            else
              {
                inherit (agentPreset) id source;
                enableTools = agentPreset.enableTools or [ ];
                name = agentPreset.name or null;
                description = agentPreset.description or null;
              };
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
        // lib.optionalAttrs (spec.agentPreset != null) {
          "${spec.targetName}/agent-preset/${spec.agentPreset.id}" = spec.agentPreset.template;
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
          spec = profileSpec name profile;
          targetName = spec.targetName;
          mode = validateMode (profile.mode or "managed");
          seeder = if mode == "managed" then "sync_managed_profile" else "seed_mutable_profile";
          agentPresetSeeder =
            if mode == "managed" then "sync_managed_agent_preset" else "seed_mutable_agent_preset";
          agentPresetInvocation =
            if spec.agentPreset == null then
              ""
            else
              ''
                ${agentPresetSeeder} ${lib.escapeShellArg spec.agentPreset.id} ${lib.escapeShellArg "${profileTemplates}/${targetName}/agent-preset/${spec.agentPreset.id}"} "$home/.agent-presets/${spec.agentPreset.id}"
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
            [ -f "$destination/.nix-managed" ] || die "refusing to take over existing unmanaged Agent Preset '$preset' at $destination"
            grep -Fxq 'owner=nix' "$destination/.nix-managed" \
              || die "Agent Preset marker has an unexpected owner: $destination/.nix-managed"
            grep -Fxq "preset=$preset" "$destination/.nix-managed" \
              || die "Agent Preset marker belongs to another preset: $destination/.nix-managed"
          else
            mkdir -p "$destination"
          fi
        }

        copy_agent_preset_tree() {
          local source=$1
          local destination=$2

          [ -d "$source" ] || die "managed Agent Preset source is missing: $source"
          cp -r --dereference --no-preserve=mode "$source"/. "$destination"/
        }

        sync_managed_agent_preset() {
          local preset=$1
          local source=$2
          local destination=$3

          validate_agent_preset_dir "$preset" "$destination"
          copy_agent_preset_tree "$source" "$destination"
        }

        seed_mutable_agent_preset() {
          local preset=$1
          local source=$2
          local destination=$3

          if [ -e "$destination" ]; then
            validate_agent_preset_dir "$preset" "$destination"
            return 0
          fi

          validate_agent_preset_dir "$preset" "$destination"
          copy_agent_preset_tree "$source" "$destination"
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
