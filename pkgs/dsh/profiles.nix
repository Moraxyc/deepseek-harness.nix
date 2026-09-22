{
  baseBundle,
  coreutils,
  diffutils,
  gnugrep,
  dshBundleResolver,
  headlessBundle,
  lib,
  linkFarm,
  runCommand,
  util-linux,
  writeShellApplication,
  writeText,
  writers,
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

  profileAgentPreset =
    agentPresets: name: profile:
    let
      configured = profile.agentPreset or null;
    in
    if configured == null then
      null
    else
      let
        id = validatePresetId "profiles.${name}.agentPreset" configured;
      in
      if !builtins.hasAttr id agentPresets then
        throw "dsh profile: profiles.${name}.agentPreset references undeclared agentPresets.${id}"
      else
        {
          inherit id;
          definition = validatePresetDefinition id (builtins.getAttr id agentPresets);
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
    let
      needsWeb = profileNeedsWeb profile;
      needsTui = profileNeedsTui profile;
    in
    lib.unique (
      lib.optional needsWeb webBundle
      ++ lib.optional needsTui tuiBundle
      # A profile manifest is independent from the runtime defaults. Keep
      # plain CLI profiles non-interactive instead of letting dsh fall back to
      # its interactive entrypoint during headless checks and service use.
      ++ lib.optional (!needsWeb && !needsTui) headlessBundle
      ++ (profile.bundles or [ ])
    );

  makeAgentPresetPatch =
    id: definition:
    let
      sourcePatch = "${webBundle}/lib/node_modules/@deepseek-ai/dsh-web-app/presets/${definition.source}.patch.yml";
    in
    runCommand (lib.strings.sanitizeDerivationName "dsh-agent-preset-patch-${id}")
      {
        nativeBuildInputs = [ yq-go ];
      }
      ''
        [ -f ${lib.escapeShellArg sourcePatch} ] || {
          printf 'dsh profile: shipped Agent Preset patch is missing: %s\n' ${lib.escapeShellArg definition.source} >&2
          exit 1
        }
        presetCount=$(yq -r '[.[] | .insert[] | select(.name == "@deepseek-ai/dsh-agent-preset")] | length' ${lib.escapeShellArg sourcePatch})
        [ "$presetCount" -eq 1 ] || {
          printf 'dsh profile: shipped Agent Preset patch must contain exactly one declaration: %s (found %s)\n' ${lib.escapeShellArg definition.source} "$presetCount" >&2
          exit 1
        }
        DSH_PRESET_ID=${lib.escapeShellArg id} \
          DSH_PRESET_ROW=${lib.escapeShellArg "preset-${id}"} \
          yq -o=yaml '
            [ .[] | .insert[] | select(.name == "@deepseek-ai/dsh-agent-preset") ]
            | .[0]
            | .id = strenv(DSH_PRESET_ROW)
            | .config.id = strenv(DSH_PRESET_ID)
            | del(.config.name, .config.description, .config.order)
            | [{insert: [ . ]}]
          ' ${lib.escapeShellArg sourcePatch} > "$out"
        ${lib.optionalString (definition.name != null) ''
          DSH_PRESET_NAME=${lib.escapeShellArg definition.name} \
            yq -i '.[0].insert[0].config.name = strenv(DSH_PRESET_NAME)' "$out"
        ''}
        ${lib.optionalString (definition.description != null) ''
          DSH_PRESET_DESCRIPTION=${lib.escapeShellArg definition.description} \
            yq -i '.[0].insert[0].config.description = strenv(DSH_PRESET_DESCRIPTION)' "$out"
        ''}
        ${lib.concatMapStringsSep "\n" (row: ''
          rowCount=$(DSH_PRESET_TOOL=${lib.escapeShellArg row} yq -r '[.. | select(type == "!!map") | select(.id == strenv(DSH_PRESET_TOOL))] | length' "$out")
          [ "$rowCount" -eq 1 ] || {
            printf 'dsh profile: Agent Preset row must occur exactly once: %s (found %s)\n' ${lib.escapeShellArg row} "$rowCount" >&2
            exit 1
          }
          DSH_PRESET_TOOL=${lib.escapeShellArg row} yq -i \
            'del(.. | select(type == "!!map") | select(.id == strenv(DSH_PRESET_TOOL)) | .disabled)' \
            "$out"
        '') definition.enableTools}
      '';

  profileSpec =
    agentPresets: name: profile:
    let
      targetName = profileName name;
      agentPreset = profileAgentPreset agentPresets name profile;
      bundles = profileBundles profile;
      mode = validateMode (profile.mode or "managed");
      # The manifest argument order is the Cordis patch order. Keep the base
      # layer first, then apply profile bundles in their declared order.
      bundleManifests = map (bundle: "${bundle}/nix-support/dsh-bundles.json") (
        [ baseBundle ] ++ bundles
      );
      rawPatch = profile.patch or [ ];
      agentPresetPatchFile =
        if agentPreset == null then null else makeAgentPresetPatch agentPreset.id agentPreset.definition;
      agentPresetRegistryPatchFile =
        if agentPreset == null then
          null
        else
          writers.writeYAML "dsh-profile-${targetName}-agent-preset-registry.patch.yml" [
            {
              id = "agent-preset-registry";
              config.default = agentPreset.id;
            }
          ];
      rawPatchFile =
        if lib.isList rawPatch then
          writers.writeYAML "dsh-profile-${targetName}-raw-cordis.patch.yml" rawPatch
        else
          writeText "dsh-profile-${targetName}-raw-cordis.patch.yml" rawPatch;
      patchFile =
        if agentPreset == null then
          rawPatchFile
        else
          runCommand "dsh-profile-${targetName}-cordis.patch.yml" { nativeBuildInputs = [ yq-go ]; } ''
            cp ${lib.escapeShellArg rawPatchFile} "$out"
            chmod u+w "$out"
            DSH_AGENT_PRESET_PATCH=${lib.escapeShellArg agentPresetPatchFile} \
              DSH_AGENT_PRESET_REGISTRY_PATCH=${lib.escapeShellArg agentPresetRegistryPatchFile} \
              yq -i '
                . += load(strenv(DSH_AGENT_PRESET_PATCH))
                | . += load(strenv(DSH_AGENT_PRESET_REGISTRY_PATCH))
              ' "$out"
          '';
      packageJson = runCommand "dsh-profile-${targetName}-package.json" { } ''
        mkdir -p "$out"
        ${lib.getExe dshBundleResolver} profile "$out/package.json" \
          ${lib.escapeShellArg targetName} \
          ${lib.concatStringsSep " " (map lib.escapeShellArg bundleManifests)}
      '';
    in
    {
      inherit
        agentPreset
        bundles
        mode
        packageJson
        patchFile
        targetName
        ;
    };

  makeProfileTemplate =
    spec:
    runCommand (lib.strings.sanitizeDerivationName "dsh-profile-${spec.targetName}-template")
      {
        nativeBuildInputs = [ coreutils ];
      }
      ''
        mkdir -p "$out"
        cp ${lib.escapeShellArg "${spec.packageJson}/package.json"} "$out/package.json"
        cp ${lib.escapeShellArg spec.patchFile} "$out/cordis.patch.yml"
        cp ${lib.escapeShellArg spec.workspaceFile} "$out/pnpm-workspace.yaml"
        # Fingerprint the rendered files, not the store paths, so a rebuild
        # that leaves the profile content unchanged stays a no-op.
        fingerprint=$(
          cd "$out"
          sha256sum -- ${lib.concatStringsSep " " managedFiles} | sha256sum | cut -d' ' -f1
        )
        {
          printf 'owner=nix\n'
          printf 'schema=1\n'
          printf 'profile=%s\n' ${lib.escapeShellArg spec.targetName}
          printf 'fingerprint=%s\n' "$fingerprint"
        } > "$out/.nix-managed"
      '';
  makeProfileTemplates =
    {
      profileSpecs,
    }:
    linkFarm "deepseek-harness-profiles" (
      lib.mapAttrsToList (_: spec: {
        name = spec.targetName;
        path = makeProfileTemplate spec;
      }) profileSpecs
    );

  makeProfileSeeder =
    {
      homePatchFile ? null,
      profileTemplates,
      profileSpecs,
    }:
    let
      seedInvocation =
        spec:
        let
          seeder = if spec.mode == "managed" then "sync_managed_profile" else "seed_mutable_profile";
        in
        ''
          ${seeder} ${lib.escapeShellArg spec.targetName} ${lib.escapeShellArg "${profileTemplates}/${spec.targetName}"} "$home/profiles/${spec.targetName}"
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

        read_fingerprint() {
          local marker=$1
          local line value=

          while IFS= read -r line; do
            case "$line" in
              fingerprint=*) value=''${line#fingerprint=} ;;
            esac
          done < "$marker"
          printf '%s\n' "$value"
        }

        # Must match the fingerprint written by makeProfileTemplate.
        profile_fingerprint() {
          local directory=$1
          local file

          for file in ${lib.concatStringsSep " " managedFiles}; do
            [ -f "$directory/$file" ] || return 1
          done

          (
            cd "$directory" || return 1
            sha256sum -- ${lib.concatStringsSep " " managedFiles} | sha256sum | cut -d' ' -f1
          )
        }

        profile_is_current() {
          local source=$1
          local destination=$2
          local declared recorded actual

          # Declared and installed markers must agree, and the installed files
          # must still hash to the recorded fingerprint.
          declared=$(read_fingerprint "$source/.nix-managed")
          [ -n "$declared" ] || die "managed profile source has no fingerprint: $source/.nix-managed"
          recorded=$(read_fingerprint "$destination/.nix-managed")
          [ "$declared" = "$recorded" ] || return 1
          actual=$(profile_fingerprint "$destination") || return 1
          [ "$actual" = "$recorded" ]
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
          fi
        }

        validate_profile_source() {
          local source=$1
          local file

          [ -d "$source" ] || die "managed profile source is missing: $source"
          for file in ${lib.concatStringsSep " " managedFiles} .nix-managed; do
            [ -f "$source/$file" ] || die "managed profile source is missing: $source/$file"
          done
        }

        install_profile_dir() {
          local source=$1
          local destination=$2
          local parent destination_mode temporary

          parent=$(dirname -- "$destination")
          destination_mode=$(stat --format='%a' -- "$parent") \
            || die "failed to inspect profile parent: $parent"

          temporary=$(mktemp -d "$parent/.''${destination##*/}.tmp.XXXXXX") \
            || die "failed to stage managed profile: $destination"
          if ! cp -r --dereference --no-preserve=mode "$source"/. "$temporary"/; then
            rm -rf --one-file-system -- "$temporary"
            die "failed to stage managed profile: $source"
          fi
          if ! chmod "$destination_mode" "$temporary"; then
            rm -rf --one-file-system -- "$temporary"
            die "failed to set managed profile mode: $destination"
          fi

          if [ -e "$destination" ] || [ -L "$destination" ]; then
            rm -rf --one-file-system -- "$temporary"
            die "profile appeared during sync: $destination"
          fi
          if ! mv --no-copy --update=none-fail -T -- "$temporary" "$destination"; then
            rm -rf --one-file-system -- "$temporary"
            die "failed to install managed profile: $destination"
          fi
        }

        sync_managed_profile() {
          local profile=$1
          local source=$2
          local destination=$3

          validate_profile_source "$source"
          validate_profile_dir "$profile" "$destination"

          if [ ! -e "$destination" ]; then
            install_profile_dir "$source" "$destination"
            return 0
          fi

          ${lib.concatStringsSep "\n" (
            map (file: "  validate_owned_file \"$destination/${file}\"") managedFiles
          )}
          validate_owned_file "$destination/.nix-managed"

          if profile_is_current "$source" "$destination"; then
            return 0
          fi

          printf 'dsh: updating managed profile: %s\n' "$profile" >&2

          ${lib.concatStringsSep "\n" (
            map (file: "  copy_owned_file \"$source/${file}\" \"$destination/${file}\"") managedFiles
          )}
          copy_owned_file "$source/.nix-managed" "$destination/.nix-managed"
        }

        seed_mutable_profile() {
          local profile=$1
          local source=$2
          local destination=$3

          validate_profile_source "$source"

          if [ -e "$destination" ] || [ -L "$destination" ]; then
            validate_profile_dir "$profile" "$destination"
            return 0
          fi

          install_profile_dir "$source" "$destination"
        }

        requested_profile=''${1:-}
      ''
      + lib.optionalString (homePatchFile != null) ''
        copy_owned_file ${lib.escapeShellArg "${homePatchFile}"} "$home/cordis.patch.yml"
      ''
      + ''
          case "$requested_profile" in
          "")
            ${lib.concatStringsSep "\n" (map seedInvocation (lib.attrValues profileSpecs))}
            ;;
          ${lib.concatStringsSep "\n" (
            map (spec: "${lib.escapeShellArg spec.targetName}) ${seedInvocation spec} ;;") (
              lib.attrValues profileSpecs
            )
          )}
          *)
            ;;
        esac
      '';
    };

  mkProfileArtifacts =
    {
      agentPresets ? { },
      defaultBundles ? [ ],
      defaultProfile ? null,
      homePatch ? null,
      profiles ? { },
    }:
    let
      workspace = {
        packages = [ "." ];
        nodeLinker = "hoisted";
        autoInstallPeers = false;
      };
      workspaceFile = writers.writeYAML "dsh-profile-pnpm-workspace.yaml" workspace;
      profileSpecs = lib.mapAttrs (
        name: profile:
        (profileSpec agentPresets name profile)
        // {
          inherit workspaceFile;
        }
      ) profiles;
      managedProfileNames = map (spec: spec.targetName) (lib.attrValues profileSpecs);
      validatedDefaultProfile =
        lib.throwIfNot (defaultProfile == null || lib.elem defaultProfile managedProfileNames)
          "dsh: defaultProfile '${defaultProfile}' is not one of the managed profiles: ${lib.concatStringsSep ", " managedProfileNames}"
          defaultProfile;
      validatedHomePatch = lib.throwIfNot (
        homePatch == null || lib.isList homePatch
      ) "dsh: homePatch must be null or a list" homePatch;
      homePatchFile =
        if validatedHomePatch == null then
          null
        else
          writers.writeYAML "dsh-home-cordis.patch.yml" validatedHomePatch;
      profileTemplates = makeProfileTemplates { inherit profileSpecs; };
      seedProfiles = makeProfileSeeder {
        inherit
          homePatchFile
          profileSpecs
          profileTemplates
          ;
      };
      runtimeBundles = lib.unique (
        defaultBundles ++ lib.concatMap (spec: spec.bundles) (lib.attrValues profileSpecs)
      );
      profilesForComposition = lib.mapAttrs (
        name: profile:
        profile
        // {
          bundles = (builtins.getAttr name profileSpecs).bundles;
        }
      ) profiles;
    in
    {
      inherit
        homePatchFile
        profileSpecs
        profileTemplates
        profilesForComposition
        runtimeBundles
        seedProfiles
        validatedHomePatch
        validatedDefaultProfile
        workspaceFile
        ;
    };
in
{
  inherit
    mkProfileArtifacts
    profileBundles
    profileNeedsTui
    profileName
    profileNeedsWeb
    renderPatch
    ;
}
