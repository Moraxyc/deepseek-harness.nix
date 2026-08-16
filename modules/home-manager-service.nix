{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dsh;
  unitName = "dsh-web";
  profileOptions = import ./profile-options.nix { inherit lib; };
  profileName = name: "nix-${name}";
  composedPackage =
    let
      managedProfiles = map profileName (lib.attrNames cfg.profiles);
    in
    if lib.elem cfg.profile managedProfiles then
      (config.programs.dsh.package.withProfiles cfg.profiles).override {
        defaultProfile = cfg.profile;
      }
    else
      pkgs.dsh.presets.web;
  execArgs = [
    "--profile"
    cfg.profile
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
in
{
  imports = [ ./shared-profile-options.nix ];

  options.services.dsh = {
    enable = lib.mkEnableOption "the DeepSeek Harness user web service";

    package = lib.mkOption {
      type = lib.types.package;
      default = composedPackage;
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

    profile = lib.mkOption {
      type = lib.types.str;
      default = "nix-web";
      description = "Materialized profile name served by the unit.";
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
      default = "${config.home.homeDirectory}/.dsh";
      description = "Directory used as `DSH_HOME`; defaults to the same location the dsh CLI uses.";
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/workspace";
      description = "Working directory used by the unit.";
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
      description = "Start the service with `default.target`.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 - - -"
      "d ${cfg.workspace} 0700 - - -"
    ];

    systemd.user.services.${unitName} = {
      Unit = {
        Description = "DeepSeek Harness web service";
        After = [ "network.target" ];
      };

      Service = {
        Type = "simple";
        WorkingDirectory = cfg.workspace;
        Environment = [
          "DSH_HOME=${cfg.dataDir}"
        ]
        ++ lib.mapAttrsToList (name: value: "${name}=${value}") cfg.environment;
        ExecStart = lib.concatStringsSep " " (
          map lib.escapeShellArg ([ (lib.getExe cfg.package) ] ++ execArgs)
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

      Install = {
        WantedBy = lib.optionals cfg.autoStart [ "default.target" ];
      };
    };
  };
}
