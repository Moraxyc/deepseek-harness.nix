{
  lib,
}:
let
  dshPatchOp = lib.types.attrs;

  agentPresetSubmodule = {
    options = {
      source = lib.mkOption {
        type = lib.types.str;
        default = "standard";
        description = ''
          Shipped Agent Preset to copy into the user preset root.
        '';
      };

      enableTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          IDs of Agent Preset rows whose `disabled` field is removed.
        '';
      };

      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional display name written to the generated preset.
        '';
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional display description written to the generated preset.
        '';
      };
    };
  };

  profileSubmodule = { name, ... }: {
    options = {
      rawName = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = name;
        description = ''
          Declared profile key without the `nix-` prefix, e.g. `tui`.
        '';
      };

      materializedName = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "nix-${name}";
        description = ''
          Profile name as materialized under `$DSH_HOME/profiles`. Use this
          for `defaultProfile` and service profile options instead of
          hardcoding the `nix-` prefix.
        '';
      };

      bundles = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = ''
          dsh bundle packages for this profile, e.g. `pkgs.dsh.bundles.tui`.
          Their package manifests are resolved during the build in list
          order and applied after the shared `@deepseek-ai/dsh-base`
          layer; later bundles override earlier Cordis configuration.
        '';
      };

      agentPreset = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          ID of an entry in `programs.dsh.agentPresets`. The preset controls the
          tool rows visible to the model; provider bundles are configured
          separately.
        '';
      };

      patch = lib.mkOption {
        type = lib.types.oneOf [
          (lib.types.listOf dshPatchOp)
          lib.types.lines
        ];
        default = [ ];
        description = ''
          The profile's `cordis.patch.yml` layer, applied after bundle
          layers. Accepts a list of Cordis patch operations or a raw YAML
          string for existing configurations.
        '';
      };

      mode = lib.mkOption {
        type = lib.types.enum [
          "managed"
          "mutable"
        ];
        default = "managed";
        description = ''
          How Nix treats this profile after it is first materialized.

          - `managed`: Nix keeps the profile in sync with the
            configuration and restores any local change on the next
            activation or `dsh` run.
          - `mutable`: Nix only seeds the profile when its directory
            does not exist yet; afterwards the user manages the profile
            with `dsh` and Nix leaves it untouched.
        '';
      };
    };
  };
in
{
  inherit agentPresetSubmodule profileSubmodule;

  mkAgentPresetsOption =
    {
      default ? { },
      defaultText ? null,
      extraDescription ? "",
    }:
    lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule agentPresetSubmodule);
      inherit default defaultText;
      example = lib.literalExpression ''
        {
          web-subagents = {
            source = "standard";
            enableTools = [ "tool-subagent-codex" ];
          };
        }
      '';
      description = ''
        Agent Preset definitions declared in Nix. The build prepares each
        declared preset and checks that its shipped source exists. Activation
        copies the selected preset into the user preset root.
        ${extraDescription}
      '';
    };

  mkProfilesOption =
    {
      default ? { },
      defaultText ? null,
      extraDescription ? "",
    }:
    lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule profileSubmodule);
      inherit default defaultText;
      example = lib.literalExpression ''
        {
          tui.bundles = [ pkgs.dsh.bundles.tui ];
        }
      '';
      description = ''
        Nix-managed dsh profiles. A profile named `tui` is materialized as
        `$DSH_HOME/profiles/nix-tui` (default `~/.dsh/profiles/nix-tui`).
        Use `profiles.tui.materializedName` to reference that materialized
        name.
        Unmanaged profile directories are never taken over.
        ${extraDescription}
      '';
    };
}
