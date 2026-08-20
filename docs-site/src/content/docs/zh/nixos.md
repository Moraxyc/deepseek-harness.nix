---
title: NixOS 集成
description: 通过 NixOS 模块启用 dsh 及其 web 服务。
---

本文介绍 `nixosModules.default` 的 NixOS 集成：启用 `dsh` CLI、声明 bundle
和 profile，以及把 web profile 作为系统服务运行。bundle 和 preset 目录见
[Bundles 和预设](../catalog/)；包覆盖、密钥注入和反向代理见
[高级用法](../advanced-usage/)。

## 添加 Flake Input

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

如果这个仓库在你的 flake 里用了其他 input 名，例如 `dsh`，请把示例中的
`inputs.deepseek-harness` 替换成对应名称。

## 启用模块

在 NixOS 配置中导入 `nixosModules.default`：

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
    defaultProfile = "nix-tui";
  };
}
```

该模块会：

- 设置 `nixpkgs.overlays`，使 `pkgs.dsh.*` scope 可用；
- 把组合后的 `dsh` 加入 `environment.systemPackages`；
- 提供 `programs.dsh` 和 `services.dsh` 两组选项。

## 设置 DSH Home

设置 `programs.dsh.home`，可通过系统环境显式导出 `DSH_HOME`：

```nix
programs.dsh.home = "/var/lib/dsh-cli";
```

未设置时，dsh 仍按用户使用默认的 `$HOME/.dsh`。

## 声明 Profile

profile 声明在 `programs.dsh.profiles` 下。名为 `tui` 的 profile 会生成到
`$DSH_HOME/profiles/nix-tui`，其中 `$DSH_HOME` 默认是 `~/.dsh`。

`programs.dsh.package` 默认是 `pkgs.dsh.dsh`；需要不同组合或包来源时，可以
覆盖这个选项。

每个 profile 支持：

- `bundles`：bundle 包列表，例如 `pkgs.dsh.bundles.tui`；
- `patch`：一组 Cordis patch 操作或原始 YAML，作为 `cordis.patch.yml`
  在所有 bundle 层之后应用；
- `mode`：`managed`（默认）或 `mutable`；
- 只读的 `rawName` 和 `materializedName`。

示例：

```nix
programs.dsh.profiles = {
  tui = {
    bundles = [
      pkgs.dsh.bundles.tui
      pkgs.dsh.bundles.web-ui
    ];
    mode = "managed";
  };
};
```

默认 profile 应使用生成后的名称，而不是硬编码 `nix-` 前缀：

```nix
{ config, inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh = {
    enable = true;
    profiles.tui.bundles = [ pkgs.dsh.bundles.tui ];
    defaultProfile = config.programs.dsh.profiles.tui.materializedName;
  };
}
```

## Profile 模式

- `managed`：每次运行 `dsh` 都会把 profile 重新同步为配置内容，因此对受
  管理的 `package.json` 和 `cordis.patch.yml` 的本地修改会被还原。
- `mutable`：仅在 profile 目录不存在时由 Nix 初始化一次；之后用户通过
  `dsh plugin` 管理，Nix 不再改动。

两种模式都不会接管已有但没有 Nix 标记的同名目录。

## 运行 Web 服务

`services.dsh` 把 web profile 作为 NixOS systemd 服务运行。默认只监听
loopback，不打开防火墙。

```nix
services.dsh = {
  enable = true;
  listenAddress = "127.0.0.1";
  port = 3080;
  trustedHosts = [ "dsh.example.com" ];
};
```

默认服务运行 `nix-web`。如果声明了 `programs.dsh.profiles.web`，服务会从
`programs.dsh.package` 和这些 profile 组合运行包；否则回退到 web preset。

主要服务选项：

- `profile`：服务运行的生成后 profile 名，默认 `nix-web`；
- `listenAddress`、`port`、`trustedHosts`：监听地址、端口和浏览器信任域名；
- `extraArguments`：追加到 `dsh` 命令的参数；
- `user`、`group`：固定服务账号；两者都不设置时使用 `DynamicUser`；
- `dataDir`、`homeDirectory`、`workspace`：状态和工作路径；
- `environment`、`environmentFile`、`credentials`：运行时环境变量和密钥来源；
- `openFirewall`：是否打开 `port`，默认 `false`；
- `autoStart`：是否随 `multi-user.target` 启动，默认 `true`。

如果需要更严格的沙箱，可启用可选的 systemd 隔离模式。该模式保留 web
服务所需的网络能力，同时增加设备、内核、命名空间、能力以及 SUID/SGID
限制。额外的可写路径和绑定挂载必须显式声明：

```nix
services.dsh.isolation = {
  enable = true;
  rootDirectory = "/var/lib/dsh/root";
  readWritePaths = [ "/var/lib/dsh/cache" ];
  bindPaths = [ "/srv/dsh-assets:/opt/dsh/assets" ];
  bindReadOnlyPaths = [ "/nix/store:/nix/store" "/etc/resolv.conf:/etc/resolv.conf" ];
};
```

`rootDirectory` 是可选项。设置后该目录会作为服务根目录，程序运行时依赖
必须位于根目录中。请使用 `bindReadOnlyPaths` 显式挂载所需的 Nix store、证书、
DNS 文件或其他只读输入。两个 bind 选项都使用 systemd 的
`source:destination` 格式。隔离模式下服务的 `homeDirectory` 和 `workspace`
仍然可写；`readWritePaths` 用于追加其他可写路径。

服务单元名为 `dsh-web`：

```sh
sudo systemctl start dsh-web
sudo systemctl restart dsh-web
systemctl status dsh-web
journalctl -u dsh-web -f
```

服务默认使用 systemd `DynamicUser`，状态放在 `/var/lib/dsh`。反向代理、
密钥文件、credentials、固定用户/组模式和完整服务选项见
[高级用法](../advanced-usage/)。

## 排错

- 如果 NixOS 模块求值时出现 `attribute 'dsh' missing`，检查是否导入了
  `nixosModules.default`，以及是否有其他模块用不包含 dsh overlay 的固定
  `pkgs` 替换了默认包集。
- 如果 flake 通过 `specialArgs` 向 `nixosSystem` 传入 `pkgs`，NixOS 会忽略
  `nixpkgs.overlays`。应使用已经包含 dsh overlay 的 pkgs；复用一个已有 pkgs
  时，导入 `inputs.nixpkgs.nixosModules.readOnlyPkgs` 并把 `nixpkgs.pkgs`
  指向该 pkgs。
- 如果 `dsh` 启动后没有使用预期 profile，检查 `programs.dsh.defaultProfile`
  是否使用了生成后的名称（`nix-tui`），而不是原始 profile key（`tui`）。
