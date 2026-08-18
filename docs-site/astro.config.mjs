import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

export default defineConfig({
  site: "https://moraxyc.github.io",
  base: "/deepseek-harness.nix",
  trailingSlash: "always",
  integrations: [
    starlight({
      title: "DeepSeek Harness Nix",
      defaultLocale: "root",
      locales: {
        root: { label: "English", lang: "en" },
        zh: { label: "简体中文", lang: "zh-CN" },
      },
      customCss: ["./src/styles/custom.css"],
      sidebar: [
        {
          label: "Documentation",
          translations: { "zh-CN": "文档" },
          items: [
            { label: "Home", slug: "index", translations: { "zh-CN": "首页" } },
            {
              label: "Getting Started",
              slug: "getting-started",
              translations: { "zh-CN": "快速开始" },
            },
            {
              label: "Bundles and Presets",
              slug: "catalog",
              translations: { "zh-CN": "Bundles 和预设" },
            },
            { label: "NixOS", slug: "nixos" },
            { label: "Home Manager", slug: "home-manager" },
            {
              label: "Advanced Usage",
              slug: "advanced-usage",
              translations: { "zh-CN": "高级用法" },
            },
            {
              label: "Development",
              slug: "development",
              translations: { "zh-CN": "开发说明" },
            },
          ],
        },
      ],
    }),
  ],
});
