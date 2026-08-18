---
title: Getting Started
description: Run DeepSeek Harness from the remote flake, choose an output, and configure Cachix.
---

## Quickstart

Try the TUI preset:

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --accept-flake-config
```

The `--accept-flake-config` flag lets Nix use the repository's configured binary cache when needed.

## Use the Remote Flake

Run or build individual outputs directly from GitHub:

```sh
nix run github:moraxyc/deepseek-harness.nix#default -- --version
nix build github:moraxyc/deepseek-harness.nix#dsh
nix build github:moraxyc/deepseek-harness.nix#dsh-desktop
nix build github:moraxyc/deepseek-harness.nix#dsh-kernel
nix build github:moraxyc/deepseek-harness.nix#dsh-workspace
nix build github:moraxyc/deepseek-harness.nix#bundles.tui
nix run github:moraxyc/deepseek-harness.nix#presets.tui
```

The main outputs are:

| Output          | Purpose                          |
| --------------- | -------------------------------- |
| `dsh`           | CLI package                      |
| `dsh-desktop`   | Desktop application              |
| `dsh-kernel`    | Kernel without profile bundles   |
| `dsh-workspace` | Built workspace artifacts        |
| `bundles.*`     | Plugin-style extensions          |
| `presets.*`     | Ready-to-use bundle combinations |

See the [Bundles and Presets](../catalog/) catalog for the complete list.

## Add It to Another Flake

Declare the repository as an input, then use `inputs.deepseek-harness.*` for its packages, modules, and overlay:

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

With the input declared, continue with the [NixOS integration](../nixos/), [Home Manager integration](../home-manager/), or [Advanced Usage](../advanced-usage/) guide.

## Cachix

Use the public cache with:

```sh
cachix use deepseek-harness-nix
```

Or add it to Nix configuration manually:

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

## License and Notice

This repository's own code and documentation are licensed under the MIT License. The license does not cover upstream `deepseek-harness`, DeepSeek or `@deepseek-ai` materials, names, or trademarks, or third-party components.

This is an independent community project. It is not affiliated with, endorsed by, or supported by DeepSeek, `@deepseek-ai`, `deepseek-harness`, or the `deepseek harness` name or trademark. See the repository [LICENSE](https://github.com/moraxyc/deepseek-harness.nix/blob/main/LICENSE) for the full terms.
