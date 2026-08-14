# deepseek-harness-nix

## 使用

```sh
nix build .#dsh
nix build .#presets.tui
nix build .#bundles.tui
nix run .#default -- --version
```

## 输出

- `dsh`
- `dsh-kernel`
- `dsh-workspace`
- `bundles.base`
- `bundles.{headless,web-app,tui}`
- `presets.{official,headless,web,tui}`

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

Nix 配置中的 `profiles.tui` 会生成到 `~/.dsh/profiles/nix-tui`。预置
profile 由 Nix 同步；已有但没有 Nix 标记的同名目录不会被接管或覆盖。

各 preset 会自动使用自己的 Nix profile。例如 `presets.tui` 默认等价于
`dsh --profile nix-tui`；显式传入 `--profile` 时仍可选择用户自己的 profile。

## 覆盖

```nix
pkgs.dsh.presets.tui.override {
  extraPlugins = [ myBundle ];
}
```

`override` 设置包输入；`withProfiles` 只替换 `profiles`，保留当前
`extraPlugins`，并清除 preset 的默认 profile。

## Overlay

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness.overlays.default ];
  environment.systemPackages = [ pkgs.dsh.dsh ];
}
```

Overlay 包位于 `pkgs.dsh` scope 中，例如 `pkgs.dsh.bundles.tui`；
flake 的 `packages` 会展开该 scope，因此仍可直接使用
`nix build .#bundles.tui` 和 `nix run .#presets.web`。
