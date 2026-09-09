{
  lib,
  pkgs,
}:
let
  profileOptions = import ./profile-options.nix { inherit lib; };
  profileName = name: "nix-${name}";

  mkComposedPackage =
    { cfg, config }:
    let
      managedProfiles = map profileName (lib.attrNames cfg.profiles);
      servicePackage =
        if lib.elem cfg.profile managedProfiles then
          (
            (config.programs.dsh.package.override {
              agentPresets = cfg.agentPresets;
            }).withProfiles
            cfg.profiles
          ).override
            {
              defaultProfile = cfg.profile;
            }
        else
          pkgs.dsh.presets.web;
    in
    servicePackage.override {
      homePatch = config.programs.dsh.patch;
    };

  mkExecArgs =
    cfg:
    [
      "--profile"
      cfg.profile
      "--no-open"
      "--host"
      cfg.listenAddress
      "--port"
      (toString cfg.port)
    ]
    ++ lib.concatMap (host: [
      "--trusted-host"
      host
    ]) cfg.trustedHosts
    ++ cfg.extraArguments;

  mkServiceConfig =
    { cfg }:
    {
      Type = "simple";
      WorkingDirectory = cfg.workspace;
      ExecStart = lib.concatStringsSep " " (
        map lib.escapeShellArg ([ (lib.getExe cfg.package) ] ++ mkExecArgs cfg)
      );
      Restart = "on-failure";
      RestartSec = "2s";
      PrivateTmp = true;
    }
    // lib.optionalAttrs (cfg.environmentFile != null) {
      EnvironmentFile = cfg.environmentFile;
    }
    // lib.optionalAttrs (cfg.credentials != { }) {
      LoadCredential = lib.mapAttrsToList (name: source: "${name}:${source}") cfg.credentials;
    };

  mkTmpfilesRules =
    { directories, owner }:
    map (directory: "d ${directory} 0700 ${owner} -") directories;

  # Host modules differ only in option text, defaults, and service wiring;
  # callers pass those in so the declarations here stay shared.
  mkOptions =
    {
      cfg,
      config,
      enableName,
      dataDirDefault,
      dataDirDefaultText ? null,
      dataDirDescription,
      workspaceDescription,
      autoStartDescription,
    }:
    {
      enable = lib.mkEnableOption enableName;

      package = lib.mkOption {
        type = lib.types.package;
        default = mkComposedPackage { inherit cfg config; };
        defaultText = lib.literalMD ''
          The web preset, or a package composed from `programs.dsh.package` and
          the declared profiles when the served profile is one of them.
        '';
        description = ''
          Composed dsh package used to serve the web profile. By default the
          unit serves the profile named by `profile` from `programs.dsh.profiles`
          (or `services.dsh.profiles`) through `programs.dsh.package`, and falls
          back to the web preset when that profile is not declared.
        '';
      };

      profiles = profileOptions.mkProfilesOption {
        default = config.programs.dsh.profiles;
        defaultText = lib.literalExpression "config.programs.dsh.profiles";
        extraDescription = ''
          This option defaults to `programs.dsh.profiles`, so custom profiles
          declared there are reused by the service automatically. Assigning
          `services.dsh.profiles` replaces the inherited profiles.
        '';
      };

      agentPresets = profileOptions.mkAgentPresetsOption {
        default = config.programs.dsh.agentPresets;
        defaultText = lib.literalExpression "config.programs.dsh.agentPresets";
        extraDescription = ''
          This option defaults to `programs.dsh.agentPresets`.
        '';
      };

      profile = lib.mkOption {
        type = lib.types.str;
        default = "nix-web";
        description = ''
          Materialized profile name served by the unit. For a declared profile,
          use `services.dsh.profiles.web.materializedName`.
        '';
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address bound by the web server. Keep this on loopback unless the firewall and proxy policy have been reviewed.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3080;
        description = "TCP port bound by the web server.";
      };

      trustedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Authorities accepted by the web API browser-trust fence, for example `dsh.example.com`.";
      };

      extraArguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments appended to the booted web profile.";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = dataDirDefault;
        defaultText = dataDirDefaultText;
        description = dataDirDescription;
      };

      workspace = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/workspace";
        description = workspaceDescription;
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables passed to the unit. Do not store secrets here.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a systemd EnvironmentFile, usually a runtime secret file.";
      };

      credentials = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "systemd LoadCredential entries; each value is a runtime source path.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = autoStartDescription;
      };
    };
in
{
  inherit
    mkOptions
    mkServiceConfig
    mkTmpfilesRules
    ;
}
