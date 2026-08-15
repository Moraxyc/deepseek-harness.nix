# 高级用法

本文覆盖 NixOS 集成、自定义 profile、覆盖方式和 Overlay。快速开始与常用命令见
[README](../README.md)。

## NixOS

导入 `nixosModules.default` 并启用 `programs.dsh`：

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

名为 `tui` 的 profile 会生成到 `$DSH_HOME/profiles/nix-tui`
（默认 `~/.dsh/profiles/nix-tui`）。Nix 只同步由它管理的 profile；已有但没有
Nix 标记的同名目录不会被接管或覆盖。

`defaultProfile` 使用生成后的名称（`nix-tui`，不是 `tui`），在没有显式传入
`--profile` 时使用。显式传入 `--profile` 时仍可选择任何可用 profile。

每个 profile 支持 `bundles` 和一层 YAML `patch`；`patch` 会作为
`cordis.patch.yml` 在 bundle 层之后应用。

## 自定义 profile

在 NixOS 之外，用 `withProfiles` 从包中生成 profile：

```nix
pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
}
```

这会生成 `nix-tui` profile，并清除默认 profile。如果需要让它成为默认，再对
结果执行 `override`：

```nix
(pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
}).override {
  defaultProfile = "nix-tui";
}
```

## 自定义 Bundle 组合

用 `withBundles` 追加 bundle。它既接受 bundle 包列表，也接受一个接收 bundle
scope 的函数，方便直接使用短名称：

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

选中的 bundle 会追加到当前组合，也会追加到包里的每个 Nix 管理 profile，
因此生成的 profile 会随这次组合同步。所有 bundle 按列表顺序应用，后面的
bundle 会覆盖前面 bundle 的 Cordis 配置；基础层固定在最前面。

## 覆盖

preset 通过 `override` 设置其他包输入；追加 bundle 请使用 `withBundles`。
`withProfiles` 只替换 `profiles`，并清除 preset 的默认 profile。

## Overlay

把 overlay 加入 Nixpkgs 后，使用 `pkgs.dsh` scope：

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness.overlays.default ];
  environment.systemPackages = [ pkgs.dsh.dsh ];
}
```

该 scope 包含 `pkgs.dsh.bundles.*`、`pkgs.dsh.presets.*`，以及
`pkgs.dsh.dsh-desktop` 等包输出。flake 的 `packages` 展开的是同一 scope，
因此 `nix build .#bundles.tui` 和 `nix run .#presets.web` 仍然可用。
