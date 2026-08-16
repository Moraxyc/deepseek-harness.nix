# deepseek-harness-nix

> **English** | [简体中文](README.md)

Nix packaging for DeepSeek Harness (`dsh`): CLI, desktop app, kernel, workspace
bundles (plugins), presets, a NixOS module, and an overlay.

## Table of Contents

- [Quickstart](#quickstart)
- [Flake Usage](#flake-usage)
- [Cachix](#cachix)
- [Bundles and Presets](#bundles-and-presets)
- [NixOS](#nixos)
- [Home Manager](#home-manager)
- [Advanced Usage](#advanced-usage)
- [Development](#development)
- [License](#license)

## Quickstart

Try the TUI preset:

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --option extra-trusted-substituters "https://deepseek-harness-nix.cachix.org"
```

## Flake Usage

Use the remote flake directly without cloning:

```sh
nix run github:moraxyc/deepseek-harness.nix#default -- --version
nix build github:moraxyc/deepseek-harness.nix#dsh
nix build github:moraxyc/deepseek-harness.nix#dsh-desktop
nix build github:moraxyc/deepseek-harness.nix#dsh-kernel
nix build github:moraxyc/deepseek-harness.nix#dsh-workspace
nix build github:moraxyc/deepseek-harness.nix#bundles.tui
nix run github:moraxyc/deepseek-harness.nix#presets.tui
```

Main outputs:

- `dsh`: CLI
- `dsh-desktop`: desktop application
- `dsh-kernel`: kernel without profile bundles
- `dsh-workspace`: built workspace artifacts
- `bundles.*` / `presets.*`: bundles and presets; see
  [Bundles and Presets](docs/bundles-presets.md) for the full catalog

The flake can also be added to another flake's inputs, then use the modules
and overlay exposed through `inputs.deepseek-harness.*`:

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

Once declared, the examples in [NixOS](#nixos),
[Home Manager](#home-manager), and [Advanced Usage](#advanced-usage) work
directly.

## Cachix

```sh
cachix use deepseek-harness-nix
```

Or add it manually to your Nix configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://deepseek-harness-nix.cachix.org" ];
    trusted-public-keys = [
      "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="
    ];
  };
}
```

## Bundles and Presets

Bundles are plugin-style extensions that can be combined into a `dsh` runtime;
presets are ready-to-use combinations. Bundles apply in list order, with later
bundles overriding earlier Cordis configuration. See
[Bundles and Presets](docs/bundles-presets.md) for the full catalog.

## NixOS

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

The `profiles.tui` option is materialized as `~/.dsh/profiles/nix-tui`.
Managed profiles are synchronized by Nix; existing unmanaged directories with
the same name are never taken over or overwritten.
Each declared profile exposes read-only `rawName` (`tui`) and
`materializedName` (`nix-tui`); use
`config.programs.dsh.profiles.tui.materializedName` for `defaultProfile` to
avoid hardcoding the prefix.

`services.dsh` runs the web profile as a loopback-only systemd service by
default and reuses `programs.dsh.profiles` directly: the served package is
composed from `programs.dsh.package` and the declared `web` profile. See
[Advanced Usage](docs/advanced-usage.md) for reverse proxy, secret injection,
and start/stop commands.

See [Advanced Usage](docs/advanced-usage.md) for module options, custom
profiles, `override` / `withProfiles` / `withBundles`, and the overlay.

## Home Manager

Import `homeModules.default` and enable `programs.dsh`. Enabling the module
adds the composed `dsh` to `home.packages` automatically:

```nix
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

`homeModules.default` shares the same `programs.dsh` options as the
NixOS module. The profile `mode` controls how Nix treats a materialized
profile:

- `managed` (default): every activation re-synchronizes the profile to the
  configuration, restoring local edits to `package.json` / `cordis.patch.yml`.
- `mutable`: Nix only seeds the profile when its directory does not exist yet;
  afterwards the user manages it with `dsh plugin` and Nix leaves it alone.

Neither mode takes over an existing unmarked directory with the same name. To
use this module, inject the overlay into Home Manager's `pkgs` (for example
pass `pkgs = import nixpkgs { overlays = [ inputs.deepseek-harness.overlays.default ]; }`
to `homeManagerConfiguration`, or use NixOS's `home-manager.useGlobalPkgs`),
or set `programs.dsh.package` explicitly.

`homeModules.default` also provides `services.dsh` for a per-user systemd
unit (`systemctl --user start dsh-web`) on non-NixOS systems. See
[Advanced Usage](docs/advanced-usage.md) for details.

## Advanced Usage

Detailed integration instructions live in
[Advanced Usage](docs/advanced-usage.md).

## Development

For repository-local builds, the dev shell, and checks, see
[Development](docs/development.md).

## License

This repository's own code and documentation are licensed under the MIT
License. See [LICENSE](LICENSE).

The MIT license covers only this repository's code and documentation. It does
not cover upstream `deepseek-harness`, DeepSeek / `@deepseek-ai` materials,
names, or trademarks, nor any third-party components; those remain subject to
their respective owners' licenses and terms.

This project is an independent community project and is not affiliated with,
endorsed by, or supported by DeepSeek, `@deepseek-ai`, `deepseek-harness`, or
the `deepseek harness` name or trademark.
