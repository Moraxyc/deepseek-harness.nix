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
  dynamicUser = cfg.user == null && cfg.group == null;
  serviceUser = if cfg.user != null then cfg.user else "dsh";
  serviceGroup = if cfg.group != null then cfg.group else serviceUser;
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
    enable = lib.mkEnableOption "the DeepSeek Harness web service";

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

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "User running the service. Leave unset with `group` to use systemd DynamicUser.";
    };

    group = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Group running the service. Leave unset with `user` to use systemd DynamicUser.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/dsh";
      description = "Parent state directory for fixed-user mode. Dynamic mode uses `/var/lib/dsh`.";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/home";
      description = "Directory used as `DSH_HOME` in fixed-user mode. Dynamic mode uses `/var/lib/dsh/home`.";
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/workspace";
      description = "Working directory for fixed-user mode. Dynamic mode uses `/var/lib/dsh/workspace`.";
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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured web port in the NixOS firewall. Keep disabled when using loopback plus a reverse proxy.";
    };

    reverseProxy = {
      enable = lib.mkEnableOption "a predefined Nginx reverse proxy in front of the web service";

      domain = lib.mkOption {
        type = lib.types.str;
        description = "Domain served through the reverse proxy, for example `dsh.example.local`.";
      };

      warn = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Print a deployment warning.";
      };
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the service with `multi-user.target`.";
    };

    isolation = {
      enable = lib.mkEnableOption "additional systemd isolation for the web service";

      rootDirectory = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional systemd `RootDirectory` for the isolated service. The
          directory must contain the service runtime; bind the required Nix
          store paths and other files with `bindReadOnlyPaths`.
        '';
      };

      readWritePaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Additional paths writable by the service in isolation mode. These
          paths are passed to systemd as `ReadWritePaths`.
        '';
      };

      bindPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Read-write bind mounts for isolation mode, in systemd's
          `source:destination` format. These paths are passed to systemd as
          `BindPaths`.
        '';
      };

      bindReadOnlyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Read-only bind mounts for `rootDirectory`, in systemd's
          `source:destination` format. These paths are passed to systemd as
          `BindReadOnlyPaths`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.mkIf (cfg.reverseProxy.enable && cfg.reverseProxy.warn) [
      ''
        dsh 不是为公开使用设计的，请勿将其暴露在公共网络上。请使用 VPN 或 SD-WAN技术保护 dsh web。
        dsh is not intended for public exposure; protect the web endpoint with a VPN or SD-WAN instead.
      ''
    ];

    users.users.dsh = lib.mkIf (!dynamicUser && serviceUser == "dsh") {
      isSystemUser = true;
      group = serviceGroup;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.dsh = lib.mkIf (!dynamicUser && serviceGroup == "dsh") { };

    systemd.tmpfiles.rules = lib.mkIf (!dynamicUser) [
      "d ${cfg.dataDir} 0700 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.homeDirectory} 0700 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.workspace} 0700 ${serviceUser} ${serviceGroup} -"
    ];

    systemd.services.${unitName} = {
      description = "DeepSeek Harness web service";
      after = [
        "network.target"
        "systemd-tmpfiles-setup.service"
      ];
      wantedBy = lib.optionals cfg.autoStart [ "multi-user.target" ];
      environment = {
        DSH_HOME = cfg.homeDirectory;
      }
      // cfg.environment;

      serviceConfig = {
        Type = "simple";
        DynamicUser = lib.mkIf dynamicUser true;
        User = lib.mkIf (!dynamicUser) serviceUser;
        Group = lib.mkIf (!dynamicUser) serviceGroup;
        StateDirectory = lib.mkIf dynamicUser [
          "dsh/home"
          "dsh/workspace"
        ];
        StateDirectoryMode = lib.mkIf dynamicUser "0700";
        WorkingDirectory = cfg.workspace;
        ExecStart = lib.concatStringsSep " " (
          map lib.escapeShellArg ([ (lib.getExe cfg.package) ] ++ execArgs)
        );
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        LoadCredential = lib.mapAttrsToList (name: source: "${name}:${source}") cfg.credentials;
        Restart = "on-failure";
        RestartSec = "2s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          cfg.homeDirectory
          cfg.workspace
        ];
      }
      // lib.optionalAttrs cfg.isolation.enable {
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectKernelLogs = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        UMask = "0077";
        RootDirectory = lib.mkIf (cfg.isolation.rootDirectory != null) cfg.isolation.rootDirectory;
        ReadWritePaths = [
          cfg.homeDirectory
          cfg.workspace
        ]
        ++ cfg.isolation.readWritePaths;
        BindPaths = cfg.isolation.bindPaths;
        BindReadOnlyPaths = cfg.isolation.bindReadOnlyPaths;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    services.nginx = lib.mkIf cfg.reverseProxy.enable {
      enable = true;
      virtualHosts.${cfg.reverseProxy.domain}.locations."/" = {
        proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };
  };
}
