{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dsh;
  common = import ./service-common.nix { inherit lib pkgs; };
  unitName = "dsh-web";
  dynamicUser = cfg.user == null && cfg.group == null;
  serviceUser = if cfg.user != null then cfg.user else "dsh";
  serviceGroup = if cfg.group != null then cfg.group else serviceUser;
in
{
  imports = [ ./shared-profile-options.nix ];

  options.services.dsh =
    common.mkOptions {
      inherit cfg config;
      enableName = "the DeepSeek Harness web service";
      dataDirDefault = "/var/lib/dsh";
      dataDirDescription = "Parent state directory for fixed-user mode. Dynamic mode uses `/var/lib/dsh`.";
      workspaceDescription = "Working directory for fixed-user mode. Dynamic mode uses `/var/lib/dsh/workspace`.";
      autoStartDescription = "Start the service with `multi-user.target`.";
    }
    // {
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

      homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/home";
        description = "Directory used as `DSH_HOME` in fixed-user mode. Dynamic mode uses `/var/lib/dsh/home`.";
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

    systemd.tmpfiles.rules = lib.mkIf (!dynamicUser) (
      common.mkTmpfilesRules {
        directories = [
          cfg.dataDir
          cfg.homeDirectory
          cfg.workspace
        ];
        owner = "${serviceUser} ${serviceGroup}";
      }
    );

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

      serviceConfig =
        common.mkServiceConfig { inherit cfg; }
        // {
          DynamicUser = lib.mkIf dynamicUser true;
          User = lib.mkIf (!dynamicUser) serviceUser;
          Group = lib.mkIf (!dynamicUser) serviceGroup;
          StateDirectory = lib.mkIf dynamicUser [
            "dsh/home"
            "dsh/workspace"
          ];
          StateDirectoryMode = lib.mkIf dynamicUser "0700";
          NoNewPrivileges = true;
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
