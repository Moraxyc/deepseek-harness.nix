---
title: 快速开始
description: 从远程 flake 运行 DeepSeek Harness，选择输出并配置 Cachix。
---

## 快速运行

尝试 TUI preset：

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --accept-flake-config
```

`--accept-flake-config` 允许 Nix 在需要时使用仓库配置的二进制缓存。

## 使用远程 Flake

直接从 GitHub 运行或构建各个输出：

```sh
nix run github:moraxyc/deepseek-harness.nix#default -- --version
nix build github:moraxyc/deepseek-harness.nix#dsh
nix build github:moraxyc/deepseek-harness.nix#dsh-desktop
nix build github:moraxyc/deepseek-harness.nix#dsh-kernel
nix build github:moraxyc/deepseek-harness.nix#dsh-workspace
nix build github:moraxyc/deepseek-harness.nix#bundles.tui
nix run github:moraxyc/deepseek-harness.nix#presets.tui
```

主要输出如下：

| 输出            | 用途                          |
| --------------- | ----------------------------- |
| `dsh`           | CLI 包                        |
| `dsh-desktop`   | 桌面应用                      |
| `dsh-kernel`    | 不带 profile bundle 的 kernel |
| `dsh-workspace` | 构建后的 workspace 产物       |
| `bundles.*`     | 插件式扩展                    |
| `presets.*`     | 开箱即用的 bundle 组合        |

完整列表见 [Bundles 和预设](../catalog/)目录。

## 加入其他 Flake

声明仓库为 input，然后使用 `inputs.deepseek-harness.*` 暴露的包、模块和 overlay：

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

声明 input 后，继续阅读 [NixOS 集成](../nixos/)、[Home Manager 集成](../home-manager/)或[高级用法](../advanced-usage/)。

## Cachix

使用公开缓存：

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

## 许可证与声明

本仓库自身的代码与文档以 MIT 许可证授权。该许可证不覆盖上游 `deepseek-harness`、DeepSeek 或 `@deepseek-ai` 的材料、名称和商标，也不覆盖第三方组件。

本项目是独立社区项目，与 DeepSeek、`@deepseek-ai`、`deepseek-harness` 或 `deepseek harness` 名称/商标没有关联，也不代表上述任何一方的认可或支持。完整条款见仓库的 [LICENSE](https://github.com/moraxyc/deepseek-harness.nix/blob/main/LICENSE)。
