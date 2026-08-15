# Bundles 和预设

本目录由 flake 自动生成。请勿手工编辑。

修改 bundle 或 preset 表达式后运行 `nix run .#generate-docs`。
可使用 `nix run .#generate-docs -- --lang zh-CN --check` 校验中文目录。

## Bundles

| Flake 输出               | 包                   | 版本                  | 说明                                             |
| ------------------------ | -------------------- | --------------------- | ------------------------------------------------ |
| `bundles.ads`            | `dsh-ads`            | 0.1.0                 | DSH 广告插件，包含本地门户广告与诈骗广告仿制内容 |
| `bundles.base`           | `dsh-base`           | 0-unstable-2026-08-13 | 所有 dsh profile 共用的基础层                    |
| `bundles.better-sidebar` | `dsh-better-sidebar` | 0.12.1                | 为 DSH Web 界面提供 VSCode 风格右侧侧边栏        |
| `bundles.headless`       | `dsh-headless`       | 0-unstable-2026-08-13 | 无需图形界面即可运行 dsh                         |
| `bundles.modlens`        | `dsh-modlens`        | 3.16.6                | 为纯文本模型提供插件式视觉能力                   |
| `bundles.tui`            | `dsh-tui`            | 0.5.2                 | dsh 的交互式终端界面                             |
| `bundles.web-app`        | `dsh-web-app`        | 0-unstable-2026-08-13 | dsh 的网页界面                                   |
| `bundles.web-ui`         | `dsh-web-ui`         | 0.1.13                | 额外的 Web UI 主题与组件                         |

## 预设

| Flake 输出         | 默认 profile   | Bundles                                              | 说明                                   |
| ------------------ | -------------- | ---------------------------------------------------- | -------------------------------------- |
| `presets.headless` | `nix-headless` | `dsh-base`, `dsh-headless`                           | 适合从终端运行 dsh 的简洁组合          |
| `presets.official` | -              | `dsh-base`, `dsh-headless`, `dsh-web-app`            | 默认组合，同时包含命令行和网页选项     |
| `presets.tui`      | `nix-tui`      | `dsh-base`, `dsh-headless`, `dsh-web-app`, `dsh-tui` | 以交互式终端界面为主的组合             |
| `presets.web`      | `nix-web`      | `dsh-base`, `dsh-web-app`                            | 以网页界面为主，不包含额外 UI 组件     |
| `presets.web-ui`   | `nix-web-ui`   | `dsh-base`, `dsh-web-app`, `dsh-web-ui`              | 以网页界面为主，包含额外 UI 主题与组件 |
