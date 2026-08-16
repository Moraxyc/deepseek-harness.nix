# 高级用法

本文覆盖 NixOS 集成、自定义 profile、覆盖方式和 Overlay。快速开始与常用命令见
[README](../README.md)。

## NixOS

导入 `nixosModules.default` 并启用 `programs.dsh`：

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

名为 `tui` 的 profile 会生成到 `$DSH_HOME/profiles/nix-tui`
（默认 `~/.dsh/profiles/nix-tui`）。Nix 只同步由它管理的 profile；已有但没有
Nix 标记的同名目录不会被接管或覆盖。

`defaultProfile` 使用生成后的名称（`nix-tui`，不是 `tui`），在没有显式传入
`--profile` 时使用。显式传入 `--profile` 时仍可选择任何可用 profile。

每个 profile 支持 `bundles` 和一层 YAML `patch`；`patch` 会作为
`cordis.patch.yml` 在 bundle 层之后应用。

## NixOS Web 服务

启用 `services.dsh` 可以把 web preset 作为 systemd 单元运行。默认只监听
loopback，并且不打开防火墙。

```nix
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  services.dsh = {
    enable = true;
    profile = "nix-web";
    listenAddress = "127.0.0.1";
    port = 3080;
    trustedHosts = [ "dsh.example.com" ];
  };
}
```

服务把 `DSH_HOME` 放在 `/var/lib/dsh/home`，把
`/var/lib/dsh/workspace` 作为工作目录。如果覆盖 `dataDir`、
`homeDirectory` 或 `workspace`，请确保服务用户可写这些路径。

除非同时设置 `user` 和 `group`，单元默认使用 systemd `DynamicUser`。
Dynamic 模式把状态放在 `/var/lib/dsh`；固定用户模式会为配置的
`dataDir`、`homeDirectory` 和 `workspace` 创建对应目录。

### 自定义 profile

`services.dsh` 会从 `programs.dsh`（或 `services.dsh.profiles`）声明的
profile 组合服务包，自定义 web profile 会直接用于服务：

```nix
{
  programs.dsh.profiles.web.patch = ''
    # 针对 web profile 的 cordis patch 操作
  '';
  services.dsh.enable = true;
}
```

当 `services.dsh.profile`（默认 `nix-web`）出现在 `programs.dsh.profiles`
中时，单元会运行由 `programs.dsh.package` 与该组 profile 组合出的包；
否则回退到 web preset。`services.dsh.profiles` 支持与
`programs.dsh.profiles` 相同的 `bundles`、`patch`、`mode` 选项；显式赋值会
替换从 `programs.dsh` 继承的 profile。

### 密钥注入

不要把密钥写进 Nix 配置，使用运行时密钥来源。

`environmentFile`：

`environmentFile` 由 systemd 直接读取，与 `LoadCredential` 分开加载。

```nix
services.dsh.environmentFile = "/run/secrets/dsh.env";
```

文件使用 systemd `EnvironmentFile` 语法：

```sh
DEEPSEEK_API_KEY=...
DSH_PERMISSION_MODE=workspace-write
```

使用 sops-nix 时，把 `environmentFile` 指向渲染后的 secret：

```nix
imports = [
  inputs.sops-nix.nixosModules.sops
  inputs.deepseek-harness.nixosModules.default
];

sops.secrets."dsh-env" = { };
services.dsh.environmentFile = "/run/secrets/dsh-env";
```

使用 systemd credentials 时，用 `credentials.<name>` 指定
`LoadCredential` 来源。如果 credential 本身是环境文件，命名为 `env`，再把它
作为 `EnvironmentFile` 加载：

```nix
services.dsh = {
  credentials.env = "/run/secrets/dsh.env";
  environmentFile = "/run/credentials/dsh-web/env";
};
```

credential 会暴露在 `/run/credentials/dsh-web/<name>`。

### 反向代理

保持 `listenAddress` 为 loopback，把公网入口交给反向代理。Nginx：

```nix
services.nginx = {
  enable = true;
  virtualHosts."dsh.example.com" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
};

services.dsh.trustedHosts = [ "dsh.example.com" ];
```

Caddy：

```nix
services.caddy = {
  enable = true;
  virtualHosts."dsh.example.com".extraConfig = ''
    reverse_proxy 127.0.0.1:3080
  '';
};

services.dsh.trustedHosts = [ "dsh.example.com" ];
```

### 启停

服务单元名为 `dsh-web`，默认随 `multi-user.target` 启动。设置
`services.dsh.autoStart = false` 后需要手动启动：

```sh
sudo systemctl start dsh-web
sudo systemctl stop dsh-web
sudo systemctl restart dsh-web
systemctl status dsh-web
journalctl -u dsh-web -f
```

## Home Manager Web 服务

`homeModules.default` 还提供 `services.dsh`，为每个用户生成 systemd user
单元，让非 NixOS 用户获得等价的服务体验：

```nix
{
  imports = [ inputs.deepseek-harness.homeModules.default ];

  services.dsh = {
    enable = true;
    port = 3080;
  };
}
```

用户管理器中的单元名为 `dsh-web.service`，默认随 `default.target` 启动，
设置 `services.dsh.autoStart = false` 后需要手动启动。它默认使用 `~/.dsh`
作为 `DSH_HOME`，与 CLI 共享已生成的 profile：

```sh
systemctl --user start dsh-web
systemctl --user status dsh-web
journalctl --user -u dsh-web -f
```

选项与 NixOS 服务一致，仅不含 `user`、`group`、`openFirewall`；
`programs.dsh.profiles` 的复用规则同样适用。

## 自定义 profile

在 NixOS 之外，用 `withProfiles` 从包中生成 profile：

```nix
pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
}
```

这会生成 `nix-tui` profile，并清除默认 profile。如果需要让它成为默认，再对
结果执行 `override`：

```nix
(pkgs.dsh.dsh.withProfiles {
  tui.bundles = [ pkgs.dsh.bundles.tui ];
}).override {
  defaultProfile = "nix-tui";
}
```

## 自定义 Bundle 组合

用 `withBundles` 追加 bundle。它既接受 bundle 包列表，也接受一个接收 bundle
scope 的函数，方便直接使用短名称：

```nix
pkgs.dsh.dsh.withBundles [
  pkgs.dsh.bundles.tui
  pkgs.dsh.bundles.web-app
]

pkgs.dsh.dsh.withBundles (b: with b; [
  tui
  web-app
])
```

选中的 bundle 会追加到当前组合，也会追加到包里的每个 Nix 管理 profile，
因此生成的 profile 会随这次组合同步。所有 bundle 按列表顺序应用，后面的
bundle 会覆盖前面 bundle 的 Cordis 配置；基础层固定在最前面。

## 覆盖

preset 通过 `override` 设置其他包输入；追加 bundle 请使用 `withBundles`。
`withProfiles` 只替换 `profiles`，并清除 preset 的默认 profile。

## Overlay

把 overlay 加入 Nixpkgs 后，使用 `pkgs.dsh` scope：

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness.overlays.default ];
  environment.systemPackages = [ pkgs.dsh.dsh ];
}
```

该 scope 包含 `pkgs.dsh.bundles.*`、`pkgs.dsh.presets.*`，以及
`pkgs.dsh.dsh-desktop` 等包输出。flake 的 `packages` 展开的是同一 scope，
因此 `nix build .#bundles.tui` 和 `nix run .#presets.web` 仍然可用。
