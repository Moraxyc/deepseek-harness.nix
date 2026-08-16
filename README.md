# deepseek-harness-nix

> [English](README.en.md) | **简体中文**

DeepSeek Harness（`dsh`）的 Nix 打包：提供 `dsh`、`dsh-desktop`、
`dsh-kernel`、`dsh-workspace`，以及 bundle（插件）、preset、NixOS 模块和
overlay。

## 目录

- [快速开始](#快速开始)
- [Flake 用法](#flake-用法)
- [Cachix](#cachix)
- [Bundles 和预设](#bundles-和预设)
- [NixOS](#nixos)
- [Home Manager](#home-manager)
- [高级用法](#高级用法)
- [开发](#开发)
- [许可证](#许可证)

## 快速开始

尝试 TUI 预设：

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --option extra-trusted-substituters "https://deepseek-harness-nix.cachix.org"
```

## Flake 用法

不用 clone，可直接引用远程 flake：

```sh
nix run github:moraxyc/deepseek-harness.nix#default -- --version
nix build github:moraxyc/deepseek-harness.nix#dsh
nix build github:moraxyc/deepseek-harness.nix#dsh-desktop
nix build github:moraxyc/deepseek-harness.nix#dsh-kernel
nix build github:moraxyc/deepseek-harness.nix#dsh-workspace
nix build github:moraxyc/deepseek-harness.nix#bundles.tui
nix run github:moraxyc/deepseek-harness.nix#presets.tui
```

主要输出：

- `dsh`：CLI
- `dsh-desktop`：桌面应用
- `dsh-kernel`：不带 profile bundle 的 kernel
- `dsh-workspace`：构建后的 workspace 产物
- `bundles.*` / `presets.*`：bundle 和 preset，完整目录见
  [Bundles 和预设](docs/bundles-presets.zh-CN.md)

也可以把仓库加入使用方 flake 的 inputs，再使用
`inputs.deepseek-harness.*` 暴露的模块和 overlay：

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

声明 input 后，下面的 [NixOS](#nixos)、[Home Manager](#home-manager) 和
[高级用法](#高级用法) 示例即可直接使用。

## Cachix

使用 Cachix 时先执行：

```sh
cachix use deepseek-harness-nix
```

也可以手动加入 Nix 配置：

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

## Bundles 和预设

Bundle 是插件式扩展；preset 是开箱即用的组合。Bundle 按组合列表顺序应用，
后面的 bundle 会覆盖前面的 Cordis 配置。
完整目录见 [Bundles 和预设](docs/bundles-presets.zh-CN.md)。

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
每个声明的 profile 都暴露只读的 `rawName`（`tui`）和
`materializedName`（`nix-tui`）；`defaultProfile` 可使用
`config.programs.dsh.profiles.tui.materializedName`，避免手写前缀。

`services.dsh` 默认以只监听 loopback 的 systemd 服务运行 web profile，
并直接复用 `programs.dsh.profiles`：服务包从 `programs.dsh.package` 与声明的
`web` profile 自动组合。反向代理、密钥注入和启停命令见
[高级用法](docs/advanced-usage.zh-CN.md)。

更多模块选项、自定义 profile、`override` / `withProfiles` / `withBundles` 和 Overlay 见
[高级用法](docs/advanced-usage.zh-CN.md)。

## Home Manager

导入 `homeModules.default` 并启用 `programs.dsh`。启用后模块会把组合好的
`dsh` 自动加入 `home.packages`：

```nix
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

`homeModules.default` 与 NixOS 模块共享同一组 `programs.dsh`
选项。profile 的 `mode` 决定 Nix 对已生成目录的态度：

- `managed`（默认）：每次激活都会把 profile 同步为配置内容，本地对
  `package.json` / `cordis.patch.yml` 的修改会被还原。
- `mutable`：仅在目录不存在时初始化一次，之后 profile 由 `dsh plugin`
  管理，Nix 不再改动其中的文件。

两种模式都不会接管没有 Nix 标记的已有同名目录。使用该模块时，需要把
overlay 注入 Home Manager 的 `pkgs`（例如 `homeManagerConfiguration`
传入 `pkgs = import nixpkgs { overlays = [ inputs.deepseek-harness.overlays.default ]; }`
或使用 NixOS 的 `home-manager.useGlobalPkgs`），或者显式设置
`programs.dsh.package`。

`homeModules.default` 还提供 `services.dsh`，可为非 NixOS 用户运行
per-user systemd 服务（`systemctl --user start dsh-web`），详情见
[高级用法](docs/advanced-usage.zh-CN.md)。

## 高级用法

NixOS 参数、自定义 profile、覆盖方式和 Overlay 的详细说明见
[高级用法](docs/advanced-usage.zh-CN.md)。

## 开发

需要 clone 仓库、本地构建、进入开发 shell 或运行检查时，见
[开发文档](docs/development.zh-CN.md)。

## 许可证

本仓库自身的代码与文档以 MIT 许可证授权，完整条款见
[LICENSE](LICENSE)。

MIT 授权范围仅覆盖本仓库自身的代码与文档，不覆盖上游 `deepseek-harness`、
DeepSeek / `@deepseek-ai` 的材料、名称或商标，也不覆盖任何第三方组件；
这些内容分别适用各自权利人的许可和条款。

本项目是独立社区项目，与 DeepSeek、`@deepseek-ai`、`deepseek-harness`
及 `deepseek harness` 名称或商标没有关联，也不代表上述任何一方的认可
或支持。
