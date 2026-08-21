---
title: 开发
description: 构建、测试和维护 DSH Nix flake。
---

本文覆盖需要 clone 仓库的本地 flake 用法。远程 flake 用法见
[README](https://github.com/moraxyc/deepseek-harness.nix)。

## 获取仓库

```sh
git clone https://github.com/moraxyc/deepseek-harness.nix.git
cd deepseek-harness.nix
```

## 本地 Flake 用法

以下命令都需要在本仓库目录内执行：

```sh
nix build .#dsh
nix build .#presets.tui
nix build .#bundles.tui
nix run .#default -- --version
nix run .#dsh-desktop
```

`packages` 提供 `dsh`、`dsh-desktop`、`dsh-kernel`、`dsh-workspace`；
`bundles.*` 和 `presets.*` 通过 `legacyPackages` 暴露，因此
`nix build .#bundles.tui` 和 `nix run .#presets.tui` 这类引用同样可用。完整
目录见 [Bundles 和预设](../catalog/)。

## 开发环境

```sh
nix develop
```

默认开发 shell 包含 `jq`、`nix-update`、`nixfmt`、`pre-commit` 和
`yq-go`。pre-commit 和 flake checks 会在提交/推送前运行。

## 常用命令

```sh
nix fmt
nix flake check
nix build .#docs-site
cd docs-site
npm ci
npm run build
```

更新锁文件：

```sh
nix flake update
nix flake update --flake ./modules/flake-parts/dev
```

## 文档

所有用户可见文档保持中英双语，分别位于
`docs-site/src/content/docs/` 和 `docs-site/src/content/docs/zh/`。
