---
title: NixOS Integration
description: Enable dsh and its web service through NixOS modules.
---

This guide covers the `nixosModules.default` NixOS module: enabling the `dsh`
CLI, declaring bundles and profiles, and running the web profile as a system
service. For bundle and preset details, see
[Bundles and Presets](../catalog/). For advanced package overrides, secret
injection, and reverse proxy setup, see [Advanced Usage](../advanced-usage/).

## Add the Flake Input

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

If this repository is declared under another input name, such as `dsh`,
replace `inputs.deepseek-harness` in the examples with that name.

## Enable the Module

Import `nixosModules.default` in a NixOS configuration:

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
    defaultProfile = "nix-tui";
  };
}
```

The module:

- sets `nixpkgs.overlays` so the `pkgs.dsh.*` scope is available;
- adds a composed `dsh` package to `environment.systemPackages`;
- exposes the `programs.dsh` and `services.dsh` option groups.

## Set DSH Home

Set `programs.dsh.home` to export an explicit `DSH_HOME` through the system
environment:

```nix
programs.dsh.home = "/var/lib/dsh-cli";
```

When unset, dsh keeps its per-user `$HOME/.dsh` default.

## Manage the Home-Level Patch

`programs.dsh.patch` accepts a structured list of Cordis patch entries and
manages it as `$DSH_HOME/cordis.patch.yml`:

```nix
programs.dsh.patch = [
  {
    id = "agent-default-model";
    config = {
      provider = "deepseek-official";
      model = "deepseek-v4-flash";
    };
  }
];
```

This layer applies after each profile's own patch and therefore affects every
profile. Module-composed CLI and service packages restore the declared file
before launch. The default `null` leaves the file unmanaged.

## Declare Profiles

Profiles are declared as attributes of `programs.dsh.profiles`. A profile
named `tui` is materialized as `$DSH_HOME/profiles/nix-tui`, where
`$DSH_HOME` defaults to `~/.dsh`.

`programs.dsh.package` defaults to `pkgs.dsh.dsh` and can be overridden when
you need a different composition or package source.

Each profile supports:

- `bundles`: a list of bundle packages, e.g. `pkgs.dsh.bundles.tui`;
- `agentPreset`: optionally copy a shipped Agent Preset and remove `disabled`
  from selected row ids with `enableTools`;
- `patch`: a list of Cordis patch operations or raw YAML applied after all
  bundle layers as `cordis.patch.yml`;
- `mode`: `managed` (default) or `mutable`;
- read-only `rawName` and `materializedName`.

Example:

```nix
programs.dsh.profiles = {
  tui = {
    bundles = [
      pkgs.dsh.bundles.tui
      pkgs.dsh.bundles.web-ui
    ];
    mode = "managed";
  };
};
```

For optional Claude Code or Codex subagent tools, add the matching
`subagent-claude-code` or `subagent-codex` bundle and declare `agentPreset` as
shown in [Advanced Usage](../advanced-usage/). The provider bundle and the
model-facing preset row are separate choices.

Use the materialized name for defaults instead of hardcoding the `nix-`
prefix:

```nix
{ config, inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
    defaultProfile = config.programs.dsh.profiles.tui.materializedName;
  };
}
```

## Profile Modes

- `managed`: every `dsh` invocation re-synchronizes the profile from the
  configuration, so local changes to managed `package.json` and
  `cordis.patch.yml` are restored.
- `mutable`: Nix seeds the profile only when the directory does not exist;
  afterwards the user manages it with `dsh plugin` and Nix leaves it alone.

Neither mode takes over an existing unmarked directory with the same name.

## Run the Web Service

`services.dsh` runs the web profile as a NixOS systemd unit. It binds only to
loopback by default and does not open the firewall.

```nix
services.dsh = {
  enable = true;
  listenAddress = "127.0.0.1";
  port = 3080;
  trustedHosts = [ "dsh.example.com" ];
};
```

By default the unit serves `nix-web`. If a custom `programs.dsh.profiles.web`
profile is declared, the service composes it from `programs.dsh.package` and
those profiles; otherwise it falls back to the web preset.

Key service options:

- `profile`: materialized profile served by the unit, default `nix-web`;
- `listenAddress`, `port`, and `trustedHosts`: binding and browser-trust
  settings;
- `extraArguments`: additional arguments appended to the `dsh` command;
- `user` and `group`: fixed service account; leave both unset for
  `DynamicUser`;
- `dataDir`, `homeDirectory`, and `workspace`: state and working paths;
- `environment`, `environmentFile`, and `credentials`: runtime environment
  and secret sources;
- `openFirewall`: whether to open `port`, default `false`;
- `autoStart`: whether to start with `multi-user.target`, default `true`.

Enable the optional systemd isolation profile when the service needs a
stronger sandbox. It keeps networking available for the web server, while
adding device, kernel, namespace, capability, and SUID/SGID restrictions.
Additional writable paths and bind mounts must be declared explicitly:

```nix
services.dsh.isolation = {
  enable = true;
  rootDirectory = "/var/lib/dsh/root";
  readWritePaths = [ "/var/lib/dsh/cache" ];
  bindPaths = [ "/srv/dsh-assets:/opt/dsh/assets" ];
  bindReadOnlyPaths = [ "/nix/store:/nix/store" "/etc/resolv.conf:/etc/resolv.conf" ];
};
```

`rootDirectory` is optional. When set, the directory is the service root and
the executable's runtime must be made available below it. Use
`bindReadOnlyPaths` for the required Nix store paths, certificates, DNS files,
or other read-only inputs. Both bind options use systemd's
`source:destination` syntax. The service's `homeDirectory` and `workspace`
remain writable in isolation mode; `readWritePaths` adds more paths.

The unit is named `dsh-web`:

```sh
sudo systemctl start dsh-web
sudo systemctl restart dsh-web
systemctl status dsh-web
journalctl -u dsh-web -f
```

The service defaults to systemd `DynamicUser` and stores state under
`/var/lib/dsh`. For reverse proxies, secret files, credentials, fixed
user/group mode, and the complete service option list, see
[Advanced Usage](advanced-usage.md).

## Troubleshooting

- If `attribute 'dsh' missing` appears while evaluating a NixOS module, check
  that `nixosModules.default` is imported and that no other module replaces
  `pkgs` with a fixed package set that predates the dsh overlay.
- If your flake passes `pkgs` through `specialArgs` to `nixosSystem`, NixOS
  ignores `nixpkgs.overlays`. Use a pkgs set that already includes the dsh
  overlay. When reusing an existing pkgs set, import
  `inputs.nixpkgs.nixosModules.readOnlyPkgs` and set `nixpkgs.pkgs` to that
  pkgs set.
- If `dsh` starts but does not use the expected profile, check that
  `programs.dsh.defaultProfile` uses the materialized name (`nix-tui`), not
  the raw profile key (`tui`).
