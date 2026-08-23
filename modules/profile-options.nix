{
  lib,
}:
let
  dshPatchOp = lib.types.attrs;

  profileSubmodule =
    { name, ... }:
    {
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
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                id = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    User preset id to materialize under `$DSH_HOME/.agent-presets`.
                    The id must contain lowercase letters, digits, and hyphens,
                    and must not shadow a shipped id (`code`, `cordis`,
                    `minimal`, or `standard`).
                    用户 preset ID 必须使用小写字母、数字和连字符，且不能覆盖
                    shipped preset ID。
                  '';
                };

                source = lib.mkOption {
                  type = lib.types.str;
                  default = "standard";
                  description = ''
                    Shipped Agent Preset to copy, for example `standard`.
                  '';
                };

                enableTools = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Agent Preset row ids whose `disabled` field should be removed
                    from the copied composition, for example
                    `tool-subagent-codex`.
                  '';
                };

                name = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Optional display name for the copied Agent Preset.";
                };

                description = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Optional description for the copied Agent Preset.";
                };
              };
            }
          );
          default = null;
          description = ''
            Optional Agent Preset copied into the profile's harness home. This
            selects the model-facing rows for sessions; provider bundles still
            control whether the corresponding Host provider is installed. The
            web-app bundle is included automatically when this is set.
            可选 Agent Preset 会复制到 harness home；设置后会自动包含 web-app
            bundle，provider bundle 仍决定对应 Host provider 是否安装。
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
            profile 的 `cordis.patch.yml` 层会在 bundle 层之后应用，也支持 raw YAML
            字符串。
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
  inherit profileSubmodule;

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
