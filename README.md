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
  --accept-flake-config
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
  [Bundles 和预设](https://moraxyc.github.io/deepseek-harness.nix/zh/catalog/)

也可以把仓库加入使用方 flake 的 inputs，再使用
`inputs.deepseek-harness.*` 暴露的模块和 overlay：

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

声明 input 后，下面的 [NixOS](#nixos)、[Home Manager](#home-manager) 和
[高级用法](#高级用法) 指南即可直接使用。

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
完整目录见 [Bundles 和预设](https://moraxyc.github.io/deepseek-harness.nix/zh/catalog/)。

## NixOS

NixOS 集成见 [NixOS 集成指南](https://moraxyc.github.io/deepseek-harness.nix/zh/nixos/)。

`nixosModules.default` 会自动设置 dsh overlay，提供 `programs.dsh`
选项，并把组合后的 `dsh` 加入 `environment.systemPackages`。启用
`services.dsh` 可以以 systemd 服务运行 web profile。

## Home Manager

Home Manager 集成见 [Home Manager 集成指南](https://moraxyc.github.io/deepseek-harness.nix/zh/home-manager/)。

`homeModules.default` 会把组合后的 `dsh` 加入 `home.packages`，并在激活时
生成和同步 managed profiles。使用该模块时，必须让 Home Manager 的 `pkgs`
包含 dsh overlay；在 NixOS + `home-manager.useGlobalPkgs` 下，就是确保
NixOS 全局 `pkgs` 已包含 `inputs.deepseek-harness.overlays.default`，否则
会报 `attribute 'dsh' missing`。

## 高级用法

NixOS 参数、自定义 profile、覆盖方式和 Overlay 的详细说明见
[高级用法](https://moraxyc.github.io/deepseek-harness.nix/zh/advanced-usage/)。

## 开发

需要 clone 仓库、本地构建、进入开发 shell 或运行检查时，见
[开发文档](https://moraxyc.github.io/deepseek-harness.nix/zh/development/)。

## 许可证

本仓库自身的代码与文档以 MIT 许可证授权，完整条款见
[LICENSE](LICENSE)。

MIT 授权范围仅覆盖本仓库自身的代码与文档，不覆盖上游 `deepseek-harness`、
DeepSeek / `@deepseek-ai` 的材料、名称或商标，也不覆盖任何第三方组件；
这些内容分别适用各自权利人的许可和条款。

本项目是独立社区项目，与 DeepSeek、`@deepseek-ai`、`deepseek-harness`
及 `deepseek harness` 名称或商标没有关联，也不代表上述任何一方的认可
或支持。
