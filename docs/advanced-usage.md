# Advanced Usage

This page covers NixOS integration, custom profiles, overrides, and the
overlay. See the [README](../README.en.md) for the quickstart and common
commands.

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

Each profile supports `bundles` and a YAML `patch` layer. `patch` is applied
after the bundle layers as `cordis.patch.yml`.

## Custom Profiles

Use `withProfiles` outside NixOS to materialize profiles from packages:

```nix
pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
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
