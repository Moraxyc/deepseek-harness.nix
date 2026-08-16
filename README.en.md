# deepseek-harness-nix

> **English** | [简体中文](README.md)

Nix packaging for DeepSeek Harness (`dsh`): CLI, desktop app, kernel, workspace
bundles (plugins), presets, a NixOS module, and an overlay.

## Table of Contents

- [Quickstart](#quickstart)
- [Usage](#usage)
- [Cachix](#cachix)
- [Bundles and Presets](#bundles-and-presets)
- [NixOS](#nixos)
- [Home Manager](#home-manager)
- [Advanced Usage](#advanced-usage)
- [License](#license)

## Quickstart

Try the TUI preset:

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --option extra-trusted-substituters "https://deepseek-harness-nix.cachix.org"
```

## Usage

```sh
nix build .#dsh
nix build .#presets.tui
nix build .#bundles.tui
nix run .#default -- --version
```

Main outputs:

- `dsh`
- `dsh-desktop`
- `dsh-kernel`
- `dsh-workspace`

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

`services.dsh` runs the web profile as a loopback-only systemd service by
default. See [Advanced Usage](docs/advanced-usage.md) for reverse proxy,
secret injection, and start/stop commands.

See [Advanced Usage](docs/advanced-usage.md) for module options, custom
profiles, `override` / `withProfiles` / `withBundles`, and the overlay.

## Home Manager

Import `homeModules.default` and enable `programs.dsh`. Enabling the module
adds the composed `dsh` to `home.packages` automatically, so do not add it
again manually:

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

## Advanced Usage

Detailed integration instructions live in
[Advanced Usage](docs/advanced-usage.md).

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
