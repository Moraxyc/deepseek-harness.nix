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
