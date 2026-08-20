---
title: Home Manager Integration
description: Use DeepSeek Harness with standalone or NixOS-managed Home Manager.
---

This guide covers `homeModules.default` for standalone Home Manager and for
Home Manager managed by NixOS. It explains how `pkgs.dsh` must be made
available and how profiles are managed. For the per-user web service, see
[Advanced Usage](../advanced-usage/).

## Add the Flake Input

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

If this repository is declared under another input name, such as `dsh`,
replace `inputs.deepseek-harness` in the examples with that name.

## Make `pkgs.dsh` Available

`homeModules.default` uses `pkgs.dsh` for the default
`programs.dsh.package` and for `pkgs.dsh.bundles.*` in examples. Choose one
of these setup paths:

- standalone Home Manager: pass a `pkgs` set that already includes
  `inputs.deepseek-harness.overlays.default` to `homeManagerConfiguration`;
- NixOS-managed Home Manager: use `home-manager.useGlobalPkgs = true` and add
  the overlay to the NixOS-level `nixpkgs.overlays`;
- any setup: set `programs.dsh.package` explicitly.

## Standalone Home Manager

Example flake module:

```nix
{ inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ inputs.deepseek-harness.overlays.default ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [ ./home.nix ];
}
```

`home.nix`:

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.homeModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui = {
      bundles = [ pkgs.dsh.bundles.tui ];
      mode = "managed";
    };
    defaultProfile = "nix-tui";
  };
}
```

The module adds the composed package to `home.packages` and seeds managed
profiles during Home Manager activation.

Set `programs.dsh.home` to use another `DSH_HOME`:

```nix
{ config, ... }:
{
  programs.dsh.home = "${config.home.homeDirectory}/.local/share/dsh";
}
```

When unset, dsh uses `~/.dsh`. Home Manager exports an explicit value to the
user session and uses it during profile activation. The user service inherits
the same location unless `services.dsh.dataDir` is set separately.

Declare the home-level Cordis patch as structured data:

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

Home Manager synchronizes this list to `$DSH_HOME/cordis.patch.yml` during
activation. The composed CLI and user service restore it again before launch.
The layer applies after each profile patch; `null` leaves the file unmanaged.

## NixOS-Managed Home Manager

When Home Manager is managed by NixOS:

- enable `home-manager.useGlobalPkgs = true`;
- add `inputs.deepseek-harness.overlays.default` to the NixOS-level
  `nixpkgs.overlays`;
- import `homeModules.default` under the target user.

```nix
{ inputs, pkgs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    users.moraxyc = { config, ... }: {
      imports = [ inputs.deepseek-harness.homeModules.default ];

      programs.dsh = {
        enable = true;
        profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
        defaultProfile = config.programs.dsh.profiles.tui.materializedName;
      };
    };
  };
}
```

`home-manager.useGlobalPkgs = true` only makes Home Manager use the NixOS
global `pkgs`; it does not add the dsh overlay by itself. If that global pkgs
set lacks `dsh`, evaluation fails with `attribute 'dsh' missing`.

If you already import `nixosModules.default`, that module sets the NixOS
overlay automatically.

## Set the Package Explicitly

If you cannot inject the overlay, set `programs.dsh.package` to a dsh package
from another pkgs. You still need `pkgs.dsh.bundles.*` or an explicit bundle
list to compose profiles.

```nix
programs.dsh.package = inputs.deepseek-harness.packages.${pkgs.system}.dsh;
```

## Profile Modes

- `managed`: every activation and every `dsh` invocation re-synchronizes the
  profile from the configuration, so local changes to managed `package.json`
  and `cordis.patch.yml` are restored.
- `mutable`: Nix seeds the profile only when the directory does not exist;
  afterwards the user manages it with `dsh plugin` and Nix leaves it alone.

Neither mode takes over an existing unmarked directory with the same name.

## Per-User Web Service

`homeModules.default` also provides `services.dsh` as a systemd user unit.
It uses `programs.dsh.home` when set and otherwise defaults to `~/.dsh`, so it
shares profiles materialized by the CLI:

```nix
services.dsh = {
  enable = true;
  port = 3080;
};
```

The unit is named `dsh-web`:

```sh
systemctl --user start dsh-web
systemctl --user status dsh-web
journalctl --user -u dsh-web -f
```

The options mirror the NixOS service except `user`, `group`, and
`openFirewall`. `dataDir` defaults to `~/.dsh` and `workspace` defaults to
`~/.dsh/workspace`; `autoStart` defaults to `true`. See
[Advanced Usage](advanced-usage.md) for details.

## Troubleshooting

- `attribute 'dsh' missing` means the `pkgs` visible to `homeModules.default`
  does not contain the dsh scope. Add the overlay to that pkgs set, or set
  `programs.dsh.package` explicitly.
- In NixOS-managed Home Manager, adding `nixpkgs.overlays` inside a Home
  Manager user module is not a reliable replacement for a NixOS-level
  overlay. Use the global `nixpkgs.overlays` instead.
- If `dsh` starts but does not use the expected profile, check that
  `programs.dsh.defaultProfile` uses the materialized name (`nix-tui`), not
  the raw profile key (`tui`).
