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
  --accept-flake-config
```

## Flake Usage

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
  [Bundles and Presets](https://moraxyc.github.io/deepseek-harness.nix/catalog/)
  for the full catalog

The flake can also be added to another flake's inputs, then use the modules
and overlay exposed through `inputs.deepseek-harness.*`:

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

Once declared, the guides in [NixOS](#nixos), [Home Manager](#home-manager),
and [Advanced Usage](#advanced-usage) work directly.

## Cache

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
[Bundles and Presets](https://moraxyc.github.io/deepseek-harness.nix/catalog/)
for the full catalog.

## NixOS

See the [NixOS Integration Guide](https://moraxyc.github.io/deepseek-harness.nix/nixos/)
for the full setup.

`nixosModules.default` adds the dsh overlay automatically, exposes
`programs.dsh`, and adds a composed `dsh` package to
`environment.systemPackages`. Enable `services.dsh` to run the web profile
as a systemd service.

## Home Manager

See the [Home Manager Integration Guide](https://moraxyc.github.io/deepseek-harness.nix/home-manager/)
for the full setup.

`homeModules.default` adds the composed `dsh` to `home.packages` and seeds
managed profiles during activation. The Home Manager `pkgs` must include the
dsh overlay. With NixOS's `home-manager.useGlobalPkgs`, ensure the NixOS
global `pkgs` already includes `inputs.deepseek-harness.overlays.default`;
otherwise evaluation fails with `attribute 'dsh' missing`.

## Advanced Usage

Detailed integration instructions live in
[Advanced Usage](https://moraxyc.github.io/deepseek-harness.nix/advanced-usage/).

## Development

For repository-local builds, the dev shell, and checks, see
[Development](https://moraxyc.github.io/deepseek-harness.nix/development/).

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
