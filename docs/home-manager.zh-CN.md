# Home Manager 集成

本文介绍 `homeModules.default` 在独立 Home Manager 和由 NixOS 管理的
Home Manager 中的用法，重点说明如何让 `pkgs.dsh` 可用，以及 Nix 如何管理
profile。per-user web 服务见 [高级用法](advanced-usage.zh-CN.md)。

## 添加 Flake Input

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

如果这个仓库在你的 flake 里用了其他 input 名，例如 `dsh`，请把示例中的
`inputs.deepseek-harness` 替换成对应名称。

## 让 `pkgs.dsh` 可用

`homeModules.default` 默认从 `pkgs.dsh` 解析 `programs.dsh.package`，示例中
也会使用 `pkgs.dsh.bundles.*`。可以按以下任一方式接入：

- 独立 Home Manager：向 `homeManagerConfiguration` 传入已经包含
  `inputs.deepseek-harness.overlays.default` 的 `pkgs`；
- NixOS 管理的 Home Manager：启用 `home-manager.useGlobalPkgs = true`，并把
  overlay 加入 NixOS 级 `nixpkgs.overlays`；
- 任意方式：显式设置 `programs.dsh.package`。

## 独立 Home Manager

flake 模块示例：

```nix
{ inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ inputs.deepseek-harness.overlays.default ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [ ./home.nix ];
}
```

`home.nix`：

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.homeModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui = {
      bundles = [ pkgs.dsh.bundles.tui ];
      mode = "managed";
    };
    defaultProfile = "nix-tui";
  };
}
```

该模块会把组合后的包加入 `home.packages`，并在 Home Manager 激活时生成和
同步受管理的 profile。

## NixOS 管理的 Home Manager

当 Home Manager 由 NixOS 管理时：

- 启用 `home-manager.useGlobalPkgs = true`；
- 在 NixOS 级 `nixpkgs.overlays` 中加入
  `inputs.deepseek-harness.overlays.default`；
- 在目标用户下导入 `homeModules.default`。

```nix
{ inputs, pkgs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    users.moraxyc = { config, ... }: {
      imports = [ inputs.deepseek-harness.homeModules.default ];

      programs.dsh = {
        enable = true;
        profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
        defaultProfile = config.programs.dsh.profiles.tui.materializedName;
      };
    };
  };
}
```

`home-manager.useGlobalPkgs = true` 只是让 Home Manager 使用 NixOS 全局
`pkgs`，不会自动加入 dsh overlay。如果全局 `pkgs` 中没有 `dsh`，求值会报
`attribute 'dsh' missing`。

如果已经导入 `nixosModules.default`，该模块会自动设置 NixOS overlay。

## 显式设置 Package

如果不能注入 overlay，可以显式把 `programs.dsh.package` 设置为另一个 pkgs
中的 dsh 包。组合 profile 时仍然需要 `pkgs.dsh.bundles.*` 或显式 bundle
列表。

```nix
programs.dsh.package = inputs.deepseek-harness.packages.${pkgs.system}.dsh;
```

## Profile 模式

- `managed`：每次激活和每次运行 `dsh` 都会把 profile 重新同步为配置内容，
  因此对受管理的 `package.json` 和 `cordis.patch.yml` 的本地修改会被还原。
- `mutable`：仅在 profile 目录不存在时由 Nix 初始化一次；之后用户通过
  `dsh plugin` 管理，Nix 不再改动。

两种模式都不会接管已有但没有 Nix 标记的同名目录。

## Per-User Web 服务

`homeModules.default` 还提供 `services.dsh`，以 systemd user 单元运行。
默认使用 `~/.dsh` 作为 `DSH_HOME`，因此会与 CLI 生成的 profile 共用：

```nix
services.dsh = {
  enable = true;
  port = 3080;
};
```

单元名为 `dsh-web`：

```sh
systemctl --user start dsh-web
systemctl --user status dsh-web
journalctl --user -u dsh-web -f
```

选项与 NixOS 服务基本一致，仅不含 `user`、`group`、`openFirewall`。细节见
[高级用法](advanced-usage.zh-CN.md)。其中 `dataDir` 默认是 `~/.dsh`，
`workspace` 默认是 `~/.dsh/workspace`，`autoStart` 默认是 `true`。

## 排错

- `attribute 'dsh' missing` 表示 `homeModules.default` 看到的 `pkgs` 中
  没有 dsh scope。需要把 overlay 注入该 pkgs，或显式设置
  `programs.dsh.package`。
- 在 NixOS 管理的 Home Manager 中，在 Home Manager 用户模块里写
  `nixpkgs.overlays` 不能可靠替代 NixOS 级 overlay；应使用全局
  `nixpkgs.overlays`。
- 如果 `dsh` 启动后没有使用预期 profile，检查 `programs.dsh.defaultProfile`
  是否使用了生成后的名称（`nix-tui`），而不是原始 profile key（`tui`）。
