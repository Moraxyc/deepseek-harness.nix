# deepseek-harness-nix

## 使用

```sh
nix build .#dsh
nix build .#presets.tui
nix build .#bundles.optional.tui
nix run .#default -- --version
```

## 输出

- `dsh`
- `dsh-kernel`
- `bundles.core.base`
- `bundles.official.{headless,web-app}`
- `bundles.optional.tui`
- `presets.{official,headless,tui}`

## NixOS

```nix
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui.bundles = [ pkgs.bundles.optional.tui ];
  };
}
```

## 覆盖

```nix
pkgs.presets.tui.override {
  extraPlugins = [ myBundle ];
}
```

`override` 设置包输入；`withProfiles` 只替换 `profiles`，保留当前
`extraPlugins`。

## Overlay

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness.overlays.default ];
  environment.systemPackages = [ pkgs.dsh ];
}
```
