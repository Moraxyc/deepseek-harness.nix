# deepseek-harness-nix

> [English](README.en.md) | **简体中文**

DeepSeek Harness（`dsh`）的 Nix 打包：提供 `dsh`、`dsh-desktop`、
`dsh-kernel`、`dsh-workspace`，以及 bundle（插件）、preset、NixOS 模块和
overlay。

## 目录

- [快速开始](#快速开始)
- [使用](#使用)
- [Cachix](#cachix)
- [Bundles 和预设](#bundles-和预设)
- [NixOS](#nixos)
- [Home Manager](#home-manager)
- [高级用法](#高级用法)
- [许可证](#许可证)

## 快速开始

尝试 TUI 预设：

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --option extra-trusted-substituters "https://deepseek-harness-nix.cachix.org"
```

## 使用

```sh
nix build .#dsh
nix build .#presets.tui
nix build .#bundles.tui
nix run .#default -- --version
```

主要输出：

- `dsh`
- `dsh-desktop`
- `dsh-kernel`
- `dsh-workspace`

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

`services.dsh` 默认以只监听 loopback 的 systemd 服务运行 web profile。
反向代理、密钥注入和启停命令见
[高级用法](docs/advanced-usage.zh-CN.md)。

更多模块选项、自定义 profile、`override` / `withProfiles` / `withBundles` 和 Overlay 见
[高级用法](docs/advanced-usage.zh-CN.md)。

## Home Manager

导入 `homeModules.default` 并启用 `programs.dsh`：

```nix
{
  imports = [ inputs.deepseek-harness.homeModules.default ];

  home.packages = [ pkgs.dsh.dsh ]; # 可选，按需把 dsh 加入 PATH

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

## 高级用法

NixOS 参数、自定义 profile、覆盖方式和 Overlay 的详细说明见
[高级用法](docs/advanced-usage.zh-CN.md)。

## 许可证

本仓库自身的代码与文档以 MIT 许可证授权，完整条款见
[LICENSE](LICENSE)。

MIT 授权范围仅覆盖本仓库自身的代码与文档，不覆盖上游 `deepseek-harness`、
DeepSeek / `@deepseek-ai` 的材料、名称或商标，也不覆盖任何第三方组件；
这些内容分别适用各自权利人的许可和条款。

本项目是独立社区项目，与 DeepSeek、`@deepseek-ai`、`deepseek-harness`
及 `deepseek harness` 名称或商标没有关联，也不代表上述任何一方的认可
或支持。
