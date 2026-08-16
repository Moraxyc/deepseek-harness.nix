# Development

This page covers local flake usage that requires cloning the repository. For
remote flake usage, see [README](../README.md). For bundle and preset
maintenance, see [CONTRIBUTING](../CONTRIBUTING.md).

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
[Bundles and Presets](bundles-presets.md) for the full catalog.

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
nix run .#generate-docs -- --check
```

After changing bundle/preset or catalog sources, regenerate and commit
`docs/bundles-presets*.md`:

```sh
nix run .#generate-docs
nix run .#generate-docs -- --lang zh-CN
```

Update lock files with:

```sh
nix flake update
nix flake update --flake ./modules/flake-parts/dev
```

## Documentation

User-facing docs are maintained in English and Chinese. When changing
`docs/*.md`, keep the matching `*.md` and `*.zh-CN.md` files in sync.
