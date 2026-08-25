---
title: Advanced Usage
description: Custom profiles, package overrides, services, and reverse proxies.
---

This page covers custom profiles, overrides, and the overlay. See
[NixOS Integration](../nixos/) and [Home Manager Integration](../home-manager/)
for module setup, and the [README](https://github.com/moraxyc/deepseek-harness.nix)
for quickstart commands.

## NixOS

Import `nixosModules.default` and enable `programs.dsh`:

```nix
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
    defaultProfile = "nix-tui";
  };
}
```

A profile named `tui` is materialized at `$DSH_HOME/profiles/nix-tui`
(`~/.dsh/profiles/nix-tui` by default). Nix synchronizes only managed
profiles. Existing unmanaged directories with the same name are never taken
over or overwritten.

`defaultProfile` uses the materialized name (`nix-tui`, not `tui`) and is used
when `dsh` is invoked without an explicit `--profile`. Passing `--profile`
explicitly still selects any available profile.

Each declared profile exposes read-only `rawName` (`tui`) and
`materializedName` (`nix-tui`). In a module, use
`config.programs.dsh.profiles.tui.materializedName` for `defaultProfile` to
avoid hardcoding the prefix.

Each profile supports `bundles` and a YAML `patch` layer. `patch` is applied
after the bundle layers as `cordis.patch.yml`.

`programs.dsh.patch` manages the structured home-level
`$DSH_HOME/cordis.patch.yml`. It applies after the selected profile's patch
and is shared by every profile.

## NixOS Web Service

Enable `services.dsh` to run the web preset as a systemd unit. It binds only
to loopback by default and does not open the firewall.

```nix
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  services.dsh = {
    enable = true;
    profile = "nix-web";
    listenAddress = "127.0.0.1";
    port = 3080;
    trustedHosts = [ "dsh.example.com" ];
  };
}
```

The service keeps `DSH_HOME` under `/var/lib/dsh/home` and uses
`/var/lib/dsh/workspace` as its working directory. If you override `dataDir`,
`homeDirectory`, or `workspace`, make sure the service user can write to those
paths.

Unless `user` and `group` are both set, the unit uses systemd `DynamicUser`.
Dynamic mode keeps its state under `/var/lib/dsh`; fixed-user mode creates the
configured `dataDir`, `homeDirectory`, and `workspace` for that account.

For a stronger systemd sandbox, enable isolation explicitly:

```nix
services.dsh.isolation = {
  enable = true;
  rootDirectory = "/var/lib/dsh/root";
  readWritePaths = [ "/var/lib/dsh/cache" ];
  bindPaths = [ "/srv/dsh-assets:/opt/dsh/assets" ];
  bindReadOnlyPaths = [ "/nix/store:/nix/store" "/etc/resolv.conf:/etc/resolv.conf" ];
};
```

Isolation keeps networking available and adds device, kernel, namespace,
capability, and SUID/SGID restrictions. `homeDirectory` and `workspace` stay
writable; use `readWritePaths` for additional writable paths. `rootDirectory`
requires the executable's runtime to be available below the root; use
`bindReadOnlyPaths` for read-only runtime inputs. Both bind options use
systemd's `source:destination` syntax.

### Custom Profiles

`services.dsh` composes its package from the profiles declared under
`programs.dsh` (or `services.dsh.profiles`), so a custom web profile is served
automatically:

```nix
{
  programs.dsh.profiles.web.patch = ''
    # cordis patch operations for the web profile
  '';
  services.dsh.enable = true;
}
```

When the profile named by `services.dsh.profile` (default `nix-web`) is
declared among `programs.dsh.profiles`, the unit runs a package composed from
`programs.dsh.package` and those profiles. Otherwise it falls back to the web
preset. `services.dsh.profiles` accepts the same `bundles`, `patch`, and
`mode` options; assigning it replaces the profiles inherited from
`programs.dsh`.

### Secrets

Keep credentials out of the Nix configuration. Use a runtime secret source
instead.

`environmentFile`:

`environmentFile` is read directly by systemd, independently of
`LoadCredential`.

```nix
services.dsh.environmentFile = "/run/secrets/dsh.env";
```

The file uses systemd `EnvironmentFile` syntax:

```sh
DEEPSEEK_API_KEY=...
DSH_PERMISSION_MODE=workspace-write
```

With sops-nix, point `environmentFile` at a rendered secret:

```nix
imports = [
  inputs.sops-nix.nixosModules.sops
  inputs.deepseek-harness.nixosModules.default
];

sops.secrets."dsh-env" = { };
services.dsh.environmentFile = "/run/secrets/dsh-env";
```

With systemd credentials, use `credentials.<name>` for a `LoadCredential`
source. If the credential is an environment file, name it `env` and load it as
`EnvironmentFile`:

```nix
services.dsh = {
  credentials.env = "/run/secrets/dsh.env";
  environmentFile = "/run/credentials/dsh-web/env";
};
```

Credentials are exposed under `/run/credentials/dsh-web/<name>`.

### Reverse Proxy

Keep `listenAddress` on loopback and terminate the public side in a proxy.
Nginx:

```nix
services.nginx = {
  enable = true;
  virtualHosts."dsh.example.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
};

services.dsh.trustedHosts = [ "dsh.example.com" ];
```

Caddy:

```nix
services.caddy = {
  enable = true;
  virtualHosts."dsh.example.com".extraConfig = ''
    reverse_proxy 127.0.0.1:3080
  '';
};

services.dsh.trustedHosts = [ "dsh.example.com" ];
```

### Start and Stop

The unit is `dsh-web`. It starts with `multi-user.target` unless
`services.dsh.autoStart = false`:

```sh
sudo systemctl start dsh-web
sudo systemctl stop dsh-web
sudo systemctl restart dsh-web
systemctl status dsh-web
journalctl -u dsh-web -f
```

## Home Manager Web Service

`homeModules.default` also provides `services.dsh` for a per-user unit, giving
non-NixOS users the same service experience:

```nix
{
  imports = [ inputs.deepseek-harness.homeModules.default ];

  services.dsh = {
    enable = true;
    port = 3080;
  };
}
```

The unit is `dsh-web.service` in the user manager and starts with
`default.target` unless `services.dsh.autoStart = false`. It uses `~/.dsh` as
`DSH_HOME` by default, so it shares the profiles materialized by the CLI:

```sh
systemctl --user start dsh-web
systemctl --user status dsh-web
journalctl --user -u dsh-web -f
```

The options mirror the NixOS service except `user`, `group`, and
`openFirewall`; the same `programs.dsh.profiles` reuse rules apply.

## Custom Profiles

Use `withProfiles` outside NixOS to materialize profiles from packages:

```nix
pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
}
```

Each profile's `bundles` accepts either a list or a bundle-scope function for
short names:

```nix
pkgs.dsh.dsh.withProfiles {
  tui.bundles = b: with b; [
    tui
  ];
}
```

This creates the `nix-tui` profile and clears the default profile. To make it
the default, override the result:

```nix
(pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
}).override {
  defaultProfile = "nix-tui";
}
```

## Optional Subagent Providers

Codex and Claude Code are optional Profile Bundles. Add only the providers a
profile may use:

```nix
programs.dsh.profiles.web.bundles = with pkgs.dsh.bundles; [
  web-app
  subagent-codex
  subagent-claude-code
];
```

Installing a provider Bundle only puts its Host provider in the runtime. It does
not start Codex or Claude Code, and it does not authorize either model-facing tool. The
shipped `standard` and `code` Agent Presets keep `tool-subagent-codex` and
`tool-subagent-claude-code` disabled. Declare the preset and profile together:

```nix
programs.dsh = {
  agentPresets.web-subagents = {
    source = "standard";
    enableTools = [ "tool-subagent-codex" ];
  };

  profiles.web = {
    bundles = with pkgs.dsh.bundles; [
      web-app
      subagent-codex
    ];
    agentPreset = "web-subagents";
  };
};
```

The build copies the selected preset into
`$DSH_HOME/.agent-presets/web-subagents` and removes `disabled` only from the
listed rows. `managed` profiles sync the copy again before launch; `mutable`
profiles seed it once. Bundle installation and Agent Preset authorization are
separate: installing a bundle does not authorize its tools.

The Bundles use the versions pinned by the upstream DeepSeek Harness workspace;
they do not search `PATH`. To use separately packaged binaries from a Nixpkgs
revision or overlay, override the Bundle inputs:

```nix
programs.dsh.profiles.web.bundles = with pkgs.dsh.bundles; [
  (subagent-codex.override {
    codexPackage = pkgs.codex;
  })
  (subagent-claude-code.override {
    claudeCodePackage = pkgs.claude-code;
  })
];
```

`codexPackage` must provide `bin/codex` and `bin/codex-code-mode-host`;
`claudeCodePackage` must expose `bin/claude` as its main program. Attribute
names and availability depend on the selected Nixpkgs revision or overlays.
When overridden, the executable version follows that package instead of the
upstream workspace lock.

The Claude Agent SDK is MIT-licensed, while its bundled Claude Code payload is
unfree. Consumers selecting `subagent-claude-code` must allow that package
explicitly:

```nix
{ lib, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    package: lib.getName package == "dsh-subagent-claude-code";
}
```

## Custom Bundle Compositions

Use `withBundles` to add bundles. It accepts either a list of bundle packages
or a bundle-scope function for short names:

```nix
pkgs.dsh.dsh.withBundles [
  pkgs.dsh.bundles.tui
  pkgs.dsh.bundles.web-app
]

pkgs.dsh.dsh.withBundles (b: with b; [
  tui
  web-app
])
```

The selected bundles are added to the current composition and appended to every
managed profile on the package, so the materialized profile stays synchronized
with the runnable composition. Bundles are applied in list order, so a later
bundle overrides an earlier bundle's Cordis configuration; the base layer is
always first.

## Overrides

Presets expose `override` for package inputs, but use `withBundles` to add
bundles. `withProfiles` replaces only `profiles` and clears the preset's default
profile.

## Overlay

Add the overlay to Nixpkgs and use the `pkgs.dsh` scope:

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness.overlays.default ];
  environment.systemPackages = [ pkgs.dsh.dsh ];
}
```

The scope includes `pkgs.dsh.bundles.*`, `pkgs.dsh.presets.*`, and package
outputs such as `pkgs.dsh.dsh-desktop`. Flake `packages` expand the same
scope, so `nix build .#bundles.tui` and `nix run .#presets.web` work the same
way.
