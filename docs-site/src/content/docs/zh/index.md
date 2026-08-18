---
title: Deepseek Harness Nix
description: DeepSeek Harness 的 Nix 打包、bundles、presets 和模块。
template: splash
hero:
  tagline: 面向 DeepSeek Harness 的可复现 Nix flake
  actions:
    - text: 浏览 Bundles 和预设
      link: /deepseek-harness.nix/zh/catalog/
      icon: right-arrow
    - text: 阅读 NixOS 指南
      link: /deepseek-harness.nix/zh/nixos/
      icon: external
---

<div class="home-intro">
  <div>
    <p class="home-kicker">开放源代码 NIX FLAKE</p>
    <p class="home-intro-title">为 DSH 提供一个稳定入口。</p>
  </div>
  <p>为 DeepSeek Harness 提供包、bundle、preset 和系统模块，把可复现的项目入口集中在一个 flake 中。</p>
</div>

<nav class="home-index" aria-label="文档目录">
  <a class="home-index-item" href="catalog/">
    <span class="home-index-number">01</span>
    <span class="home-index-copy"><strong>Bundles 和预设</strong><small>查看可用输出和 profile</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="nixos/">
    <span class="home-index-number">02</span>
    <span class="home-index-copy"><strong>NixOS 集成</strong><small>通过模块启用 profile 和 web 服务</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="development/">
    <span class="home-index-number">03</span>
    <span class="home-index-copy"><strong>开发说明</strong><small>构建、扩展和维护这个 flake</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
</nav>

<div class="home-command">
  <span class="home-kicker">从这里开始</span>
  <code>nix run github:moraxyc/deepseek-harness.nix</code>
</div>
