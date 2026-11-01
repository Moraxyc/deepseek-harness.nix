# DSH Nix

> [English](README.en.md) | [简体中文](README.md) | **日本語**

DSH Nix は、DeepSeek Harness（`dsh`）向けのコミュニティメンテナンスによる Nix
パッケージングです。CLI、デスクトップアプリ、カーネル、ワークスペースバンドル
（プラグイン）、プリセット、NixOS モジュール、overlay を提供します。

## 目次

- [クイックスタート](#クイックスタート)
- [Flake の使い方](#flake-の使い方)
- [キャッシュ](#キャッシュ)
- [バンドルとプリセット](#バンドルとプリセット)
- [NixOS](#nixos)
- [Home Manager](#home-manager)
- [高度な使い方](#高度な使い方)
- [開発](#開発)
- [ブランドに関する注意](#ブランドに関する注意)
- [ライセンス](#ライセンス)

## クイックスタート

TUI プリセットを試すには、次を実行します。

```sh
nix run github:moraxyc/deepseek-harness.nix#presets.tui \
  --accept-flake-config
```

## Flake の使い方

```sh
nix run github:moraxyc/deepseek-harness.nix#default -- --version
nix build github:moraxyc/deepseek-harness.nix#dsh
nix build github:moraxyc/deepseek-harness.nix#dsh-desktop
nix build github:moraxyc/deepseek-harness.nix#dsh-desktop-official
nix build github:moraxyc/deepseek-harness.nix#dsh-kernel
nix build github:moraxyc/deepseek-harness.nix#dsh-workspace
nix build github:moraxyc/deepseek-harness.nix#bundles.tui
nix run github:moraxyc/deepseek-harness.nix#presets.tui
```

主な出力:

- `dsh`: CLI
- `dsh-desktop`: デスクトップアプリケーションのエイリアス。現在は
  `dsh-desktop-unofficial` と同じパッケージ
- `dsh-desktop-official`: アップストリームワークスペースのリリースから構築した
  デスクトップアプリケーション。Linux と Darwin に対応
- `dsh-desktop-unofficial`: anywhere-labs/deepseek-harness-desktop から構築した
  デスクトップアプリケーション。Linux と Darwin に対応
- `dsh-kernel`: プロファイルバンドルを含まないカーネル
- `dsh-workspace`: ビルド済みのワークスペース成果物
- `bundles.*` / `presets.*`: バンドルとプリセット。完全なカタログは
  [バンドルとプリセット](https://moraxyc.github.io/deepseek-harness.nix/ja/catalog/)
  を参照

各バリアントのソース、対応プラットフォーム、`dshHost` のオーバーライドについては、
[高度な使い方](https://moraxyc.github.io/deepseek-harness.nix/ja/advanced-usage/)
を参照してください。

この flake を別の flake の inputs に追加し、`inputs.deepseek-harness.*` が公開する
モジュールと overlay を使用することもできます。

```nix
{
  inputs.deepseek-harness.url = "github:moraxyc/deepseek-harness.nix";
}
```

input を宣言すれば、[NixOS](#nixos)、[Home Manager](#home-manager)、
[高度な使い方](#高度な使い方) のガイドをそのまま利用できます。

## キャッシュ

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

## バンドルとプリセット

バンドルは、`dsh` ランタイムへ組み合わせられるプラグイン形式の拡張です。
プリセットは、すぐに使える組み合わせです。バンドルはリスト順に適用され、後の
バンドルが先のバンドルの Cordis 設定を上書きします。完全なカタログは
[バンドルとプリセット](https://moraxyc.github.io/deepseek-harness.nix/ja/catalog/)
を参照してください。

## NixOS

セットアップの詳細は、
[NixOS 統合ガイド](https://moraxyc.github.io/deepseek-harness.nix/ja/nixos/)
を参照してください。

`nixosModules.default` は dsh overlay を自動的に追加し、`programs.dsh` を公開して、
構成済みの `dsh` パッケージを `environment.systemPackages` に追加します。
`services.dsh` を有効にすると、Web プロファイルを systemd サービスとして実行できます。

## Home Manager

セットアップの詳細は、
[Home Manager 統合ガイド](https://moraxyc.github.io/deepseek-harness.nix/ja/home-manager/)
を参照してください。

`homeModules.default` は、構成済みの `dsh` を `home.packages` に追加し、
アクティベーション時に管理対象プロファイルを初期化します。Home Manager の `pkgs` には、
dsh overlay を含める必要があります。NixOS の `home-manager.useGlobalPkgs` を使う場合は、
NixOS 全体の `pkgs` に `inputs.deepseek-harness.overlays.default` がすでに含まれている
ことを確認してください。含まれていない場合、評価は `attribute 'dsh' missing` で失敗します。

## 高度な使い方

統合方法の詳細は、
[高度な使い方](https://moraxyc.github.io/deepseek-harness.nix/ja/advanced-usage/)
を参照してください。

## 開発

リポジトリ内でのローカルビルド、開発シェル、チェックについては、
[開発](https://moraxyc.github.io/deepseek-harness.nix/ja/development/)
を参照してください。

## ブランドに関する注意

DSH Nix は独立したコミュニティプロジェクトであり、DeepSeek との提携、後援、認可、
推奨の関係はありません。「DeepSeek Harness」という名称は、このプロジェクトが提供する
Nix パッケージングと統合の対象を正確に説明するためだけに使用しています。

DSH Nix は、独自のプロジェクト名と視覚表現を使用しています。ブランド名と素材の使用は、
アップストリームの
[DeepSeek Harness ブランド素材使用ガイドライン](https://github.com/deepseek-ai/deepseek-harness/blob/master/BRAND_GUIDELINES.md)
に従います。

## ライセンス

このリポジトリ自体のコードとドキュメントは、MIT ライセンスの下で提供されています。
詳しくは [LICENSE](LICENSE) を参照してください。

MIT ライセンスの適用対象は、このリポジトリ自体のコードとドキュメントだけです。
アップストリームの `deepseek-harness`、DeepSeek / `@deepseek-ai` の素材、サードパーティー
コンポーネントは対象外であり、それぞれの権利者が定めるライセンスと条件が適用されます。
