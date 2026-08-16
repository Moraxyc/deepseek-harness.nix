# Bundles 和预设

本目录由 flake 自动生成，仅作参考。请勿手工编辑。

Bundle 即插件式扩展。按顺序拼接需要的 bundle，就能得到自己的组合；后面的
bundle 会覆盖前面的 Cordis 配置。例如给已有 preset 追加 bundle：
`pkgs.dsh.presets.web-ui.withBundles [ pkgs.dsh.bundles.tui ]`；
或在 NixOS 中自定义 profile：`programs.dsh.profiles.mine.bundles = [ ... ]`。
详见 [README](../README.md)。

## Bundles

| Flake 输出               | 包                                | 版本                  | 说明                                                                                                                        |
| ------------------------ | --------------------------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `bundles.ads`            | `dsh-ads`                         | 0.1.0                 | DSH 广告插件，包含本地门户广告与诈骗广告仿制内容 · [主页](https://github.com/Nagi-ovo/dsh-ads)                              |
| `bundles.at-file`        | `dsh-at-file`                     | 0.6.0                 | 为 DeepSeek Harness 网页界面提供 Codex 风格 @路径引用 · [主页](https://github.com/omdsh-dev/dsh-at-file)                    |
| `bundles.base`           | `dsh-base`                        | 0-unstable-2026-08-13 | 所有 dsh profile 共用的基础层 · [主页](https://github.com/deepseek-ai/deepseek-harness)                                     |
| `bundles.better-sidebar` | `dsh-better-sidebar`              | 0.12.1                | 为 DSH Web 界面提供 VSCode 风格右侧侧边栏 · [主页](https://github.com/omdsh-dev/DSH-better-sidebar)                         |
| `bundles.headless`       | `dsh-headless`                    | 0-unstable-2026-08-13 | 无需图形界面即可运行 dsh · [主页](https://github.com/deepseek-ai/deepseek-harness)                                          |
| `bundles.liang-skin`     | `dsh-client-liang-intensity-skin` | 0.1.3                 | 为 DeepSeek Harness 提供滑动变祖推理等级滑块皮肤 · [主页](https://github.com/kingOfSoySauce/dsh-liang-skin)                 |
| `bundles.modlens`        | `dsh-modlens`                     | 3.16.6                | 为纯文本模型提供插件式视觉能力 · [主页](https://github.com/liustack/modlens)                                                |
| `bundles.oh-dsh`         | `oh-dsh`                          | 0.1.4                 | Oh-DSH Web：带 Oh-DSH 插件能力的 DeepSeek Harness 浏览器运行环境 · [主页](https://github.com/hust-open-atom-club/oh-dsh)    |
| `bundles.tianshu-tui`    | `dsh-tianshu-tui`                 | 0.1.2-rc.6            | dsh 的交互式 TUI 层，提供渲染、面板与终端控制 · [主页](https://github.com/huiliyi37/dsh-tianshu-tui)                        |
| `bundles.tui`            | `dsh-tui`                         | 0.5.2                 | dsh 的交互式终端界面 · [主页](https://github.com/ccch1mneyyy/dsh-TUI)                                                       |
| `bundles.vision-toolkit` | `dsh-vision-toolkit`              | 0.1.7                 | DeepSeek Harness 原生视觉工具集，支持 OCR、定位、像素差异与 UI 还原 · [主页](https://github.com/Anionex/dsh-vision-toolkit) |
| `bundles.web-app`        | `dsh-web-app`                     | 0-unstable-2026-08-13 | dsh 的网页界面 · [主页](https://github.com/deepseek-ai/deepseek-harness)                                                    |
| `bundles.web-ui`         | `dsh-web-ui`                      | 0.1.16                | 额外的 Web UI 主题与组件 · [主页](https://github.com/zhu1090093659/dsh-web-ui)                                              |

## 预设

| Flake 输出         | 默认 profile   | Bundles                                              | 说明                                                                                                  |
| ------------------ | -------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `presets.ads`      | `nix-ads`      | `dsh-base`, `dsh-web-app`, `dsh-ads`                 | 带本地门户广告与诈骗广告仿制内容的 DSH 组合 · [主页](https://github.com/deepseek-ai/deepseek-harness) |
| `presets.headless` | `nix-headless` | `dsh-base`, `dsh-headless`                           | 适合从终端运行 dsh 的简洁组合 · [主页](https://github.com/deepseek-ai/deepseek-harness)               |
| `presets.official` | -              | `dsh-base`, `dsh-headless`, `dsh-web-app`            | 默认组合，同时包含命令行和网页选项 · [主页](https://github.com/deepseek-ai/deepseek-harness)          |
| `presets.tui`      | `nix-tui`      | `dsh-base`, `dsh-headless`, `dsh-web-app`, `dsh-tui` | 以交互式终端界面为主的组合 · [主页](https://github.com/deepseek-ai/deepseek-harness)                  |
| `presets.web`      | `nix-web`      | `dsh-base`, `dsh-web-app`                            | 以网页界面为主，不包含额外 UI 组件 · [主页](https://github.com/deepseek-ai/deepseek-harness)          |
| `presets.web-ui`   | `nix-web-ui`   | `dsh-base`, `dsh-web-app`, `dsh-web-ui`              | 以网页界面为主，包含额外 UI 主题与组件 · [主页](https://github.com/deepseek-ai/deepseek-harness)      |
