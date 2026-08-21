---
title: DSH Nix
description: DeepSeek Harness 的 Nix 打包、bundles、presets 和模块。
template: splash
hero:
  tagline: 面向 DeepSeek Harness 的可复现 Nix flake，将包、预设和系统集成集中在一个入口中。
  actions:
    - text: 快速开始
      link: /deepseek-harness.nix/zh/getting-started/
      icon: right-arrow
    - text: 浏览 Bundles 和预设
      link: /deepseek-harness.nix/zh/catalog/
      icon: external
---

<div class="home-brand" aria-label="DSH Nix">
  <span>DSH Nix</span>
</div>

<section class="home-start" aria-labelledby="quickstart-title">
  <div class="home-start-copy">
    <p class="home-kicker">快速开始</p>
    <h2 id="quickstart-title">运行 TUI preset</h2>
    <p>直接启动一个可用的终端 profile，无需先克隆仓库。</p>
  </div>
  <div class="home-start-card">
    <p class="home-start-label">在任意终端运行</p>
    <code>nix run github:moraxyc/deepseek-harness.nix#presets.tui</code>
    <a class="home-start-link" href="getting-started/">
      查看快速开始 <span aria-hidden="true">↗</span>
    </a>
  </div>
</section>

<div class="home-index-heading">
  <p class="home-kicker">浏览文档</p>
  <p>选择一个方向，继续开始。</p>
</div>

<nav class="home-index" aria-label="文档目录">
  <a class="home-index-item" href="catalog/">
    <span class="home-index-number">01</span>
    <span class="home-index-copy"><strong>Bundles 和预设</strong><small>查看可用输出和 profile</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="getting-started/">
    <span class="home-index-number">02</span>
    <span class="home-index-copy"><strong>快速开始</strong><small>远程 flake 命令、输出和 Cachix</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="nixos/">
    <span class="home-index-number">03</span>
    <span class="home-index-copy"><strong>NixOS 集成</strong><small>通过模块启用 profile 和 web 服务</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="development/">
    <span class="home-index-number">04</span>
    <span class="home-index-copy"><strong>开发说明</strong><small>构建、扩展和维护这个 flake</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
</nav>
