# deepseek-harness-nix

> **English** | [简体中文](README.md)

Nix packaging for DeepSeek Harness (`dsh`), including the kernel, workspace
bundles, presets, a NixOS module, and an overlay.

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

## Outputs

- `dsh`
- `dsh-kernel`
- `dsh-workspace`
- [Bundles and Presets](docs/bundles-presets.md)

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

Each preset uses its own Nix profile by default. For example, `presets.tui` is
equivalent to `dsh --profile nix-tui`. Passing `--profile` explicitly still
lets you select your own profile.

## Overrides

```nix
pkgs.dsh.presets.tui.override {
  extraPlugins = [ myBundle ];
}
```

`override` sets package inputs. `withProfiles` only replaces `profiles`, keeps
the current `extraPlugins`, and clears the preset's default profile.

## Overlay

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness.overlays.default ];
  environment.systemPackages = [ pkgs.dsh.dsh ];
}
```

Overlay packages live under the `pkgs.dsh` scope, for example
`pkgs.dsh.bundles.tui`. Flake `packages` expand that scope, so
`nix build .#bundles.tui` and `nix run .#presets.web` continue to work.

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
