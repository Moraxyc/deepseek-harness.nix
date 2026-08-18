---
title: Development
description: Build, test, and maintain the DeepSeek Harness Nix flake.
---

This page covers local flake usage that requires cloning the repository. For
remote flake usage, see the [README](https://github.com/moraxyc/deepseek-harness.nix).

## Cloning

```sh
git clone https://github.com/moraxyc/deepseek-harness.nix.git
cd deepseek-harness.nix
```

## Local Flake Usage

Run these commands from the repository root:

```sh
nix build .#dsh
nix build .#presets.tui
nix build .#bundles.tui
nix run .#default -- --version
nix run .#dsh-desktop
```

`packages` provides `dsh`, `dsh-desktop`, `dsh-kernel`, and `dsh-workspace`.
`bundles.*` and `presets.*` are exposed through `legacyPackages`, so refs such
as `.#bundles.tui` and `.#presets.tui` work directly. See
[Bundles and Presets](../catalog/) for the full catalog.

## Dev Shell

```sh
nix develop
```

The default dev shell includes `jq`, `nix-update`, `nixfmt`, `pre-commit`, and
`yq-go`. Pre-commit and flake checks run before push.

## Common Commands

```sh
nix fmt
nix flake check
nix build .#docs-site
cd docs-site
npm ci
npm run build
```

Update lock files with:

```sh
nix flake update
nix flake update --flake ./modules/flake-parts/dev
```

## Documentation

User-facing docs are maintained in English and Chinese under
`docs-site/src/content/docs/` and `docs-site/src/content/docs/zh/`.
