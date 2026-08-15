# deepseek-harness-nix

> [English](README.en.md) | **简体中文**

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

## Cachix

```sh
cachix use deepseek-harness-nix
```

或者手动加入 Nix 配置：

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

## 输出

- `dsh`
- `dsh-desktop`
- `dsh-kernel`
- `dsh-workspace`
- [Bundles 和预设](docs/bundles-presets.zh-CN.md)

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

## License

本仓库自身的代码与文档以 MIT 许可证授权，完整条款见
[LICENSE](LICENSE)。

MIT 授权范围仅覆盖本仓库自身的代码与文档，不覆盖上游 `deepseek-harness`、
DeepSeek / `@deepseek-ai` 的材料、名称或商标，也不覆盖任何第三方组件；
这些内容分别适用各自权利人的许可和条款。

本项目是独立社区项目，与 DeepSeek、`@deepseek-ai`、`deepseek-harness`
及 `deepseek harness` 名称或商标没有关联，也不代表上述任何一方的认可
或支持。
