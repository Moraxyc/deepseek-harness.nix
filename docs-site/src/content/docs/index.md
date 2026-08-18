---
title: DeepSeek Harness Nix
description: Nix packaging, bundles, presets, and modules for DeepSeek Harness.
template: splash
hero:
  tagline: A reproducible Nix flake for DeepSeek Harness, with packages, presets, and system integration in one place.
  actions:
    - text: Get started
      link: /deepseek-harness.nix/getting-started/
      icon: right-arrow
    - text: Explore bundles and presets
      link: /deepseek-harness.nix/catalog/
      icon: external
---

<div class="home-brand" aria-label="DeepSeek Harness">
  <img src="/deepseek-harness.nix/deepseek-harness-logo.svg" alt="" width="42" height="42" />
  <span>DeepSeek Harness</span>
</div>

<section class="home-start" aria-labelledby="quickstart-title">
  <div class="home-start-copy">
    <p class="home-kicker">QUICKSTART</p>
    <h2 id="quickstart-title">Run the TUI preset</h2>
    <p>Start with a ready-to-use terminal profile. No local clone required.</p>
  </div>
  <div class="home-start-card">
    <p class="home-start-label">Run from any terminal</p>
    <code>nix run github:moraxyc/deepseek-harness.nix#presets.tui</code>
    <a class="home-start-link" href="getting-started/">
      View the quickstart <span aria-hidden="true">↗</span>
    </a>
  </div>
</section>

<div class="home-index-heading">
  <p class="home-kicker">EXPLORE THE DOCS</p>
  <p>Choose a path and keep moving.</p>
</div>

<nav class="home-index" aria-label="Documentation index">
  <a class="home-index-item" href="catalog/">
    <span class="home-index-number">01</span>
    <span class="home-index-copy"><strong>Bundles &amp; presets</strong><small>Catalog of available outputs and profiles</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="getting-started/">
    <span class="home-index-number">02</span>
    <span class="home-index-copy"><strong>Getting started</strong><small>Remote flake commands, outputs, and Cachix</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="nixos/">
    <span class="home-index-number">03</span>
    <span class="home-index-copy"><strong>NixOS integration</strong><small>Modules for profiles and the web service</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
  <a class="home-index-item" href="development/">
    <span class="home-index-number">04</span>
    <span class="home-index-copy"><strong>Development</strong><small>Build, extend, and maintain the flake</small></span>
    <span class="home-index-arrow" aria-hidden="true">→</span>
  </a>
</nav>
