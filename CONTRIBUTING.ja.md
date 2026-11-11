# 貢献ガイド

## バンドルビルダーの選択

バンドルのソースの由来に応じたビルダーを使用してください。

- `buildDshBundle`: スタンドアロンの npm ソース。カスタムレイアウトが必要な場合を除き、
  `buildNpmPackage` 標準の `npmInstallHook` でインストールします。
- `buildDshBundle.fromPnpmWorkspace`: 外部の pnpm モノレポ。選択したワークスペース
  パッケージを `$out/lib` に直接デプロイします。
- `buildDshBundle.fromWorkspace`: `dsh-workspace` によってすでにデプロイ済みの
  アップストリームパッケージとそのプロダクションクロージャ。

すべてのビルダーは同じバンドル検証を実行します。`$out/lib/node_modules` には
`dsh.bundle.patch` を宣言するパッケージが少なくとも 1 つ含まれている必要があり、
パッチファイルはそのパッケージのルートからの相対パスに存在しなければなりません。

## インストールのパッケージ

バンドルはプロファイルにリンクされ、`dsh-runtime` インストールから peer を解決します。
`installation = dsh-runtime` を設定すると、このヘルパーはインストールの `@deepseek-ai` パッケージと、
同じバージョンのその他のパッケージをインストールへのリンクに置き換え、パッケージごとのランタイムインスタンスを
1 つに保ちます。バンドル内にローカルで保持する必要があるパッケージには
`installationKeep` を使用してください。インストールに既に含まれるバンドルは
`buildDshBundle.fromInstallation` を使用し、名前で選択されます。

## CUA ヘルパー

`dsh-cua-native` は固定した Nixpkgs ツールチェーンを使用し、`dsh-workspace.src` から
Swift ヘルパーをビルドします。上流の `build_app.py` が release アプリを組み立て、
`current.json` を書き込みます。Nix パッチはその `codesign` 呼び出しを `rcodesign` による
アドホック署名に置き換えます。ビルドはアドホック署名のみに対応し、他の署名 ID や
キーチェーンを指定すると失敗します。インストール検査は macOS Security で署名を検証し、
ダイジェストを確認して、改変したコピーが検証に失敗することを確かめます。検査は静的な検証のみを行います。

## 外部 pnpm ワークスペースバンドルの追加

外部モノレポのバンドルには、`buildDshBundle.fromPnpmWorkspace` を使用してください。
このビルダーは、サポート対象の pnpm deploy プロトコルを管理し、標準の `$out/lib`
レイアウトを直接生成します。

バンドルのディレクトリ名は `bundles.*` 以下の flake 出力名になるため、アップストリーム
パッケージを `pkgs/bundles/` に配置する際は `dsh-` プレフィックスを取り除いてください。
たとえば、`dsh-ads` は `pkgs/bundles/ads` と `bundles.ads` になります。Nix パッケージの
`pname` には、アップストリーム名をそのまま使用できます。

最小テンプレート:

```nix
{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  pnpmConfigHook,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";

  deployPackage = "@example/bundle";
  stripPrepareScripts = true;

  src = fetchFromGitHub {
    owner = "example";
    repo = "example-bundle";
    rev = "0000000000000000000000000000000000000000";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  pnpmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postNormalizeDeploy = ''
    # Optional bundle-specific checks or cleanup.
  '';

  meta = {
    description = "Example DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromPnpmWorkspace` は、バンドルの derivation で次の操作を実行します。

1. `stripPrepareScripts = true` の場合、pnpm がソースパッケージを再ビルドしないよう、
   デプロイ前にワークスペースの `prepare` スクリプトを削除します。これは、
   `packages/*` を使用する pnpm ワークスペースと、`packages: ["."]` のみを定義する
   単一パッケージのワークスペースの両方をサポートします。
2. `pnpm config set --location=project inject-workspace-packages true` を実行します。
3. `fromPnpmWorkspace` は、DSH パッケージスコープの `fetchPnpmDeps` を使用して
   `pnpmDepsHash` から `pnpmDeps` を構築します。この `fetchPnpmDeps` は、デフォルトで
   `pnpmWorkspaceDeploy` を使用します。ワークスペース注入を伴う `pnpm deploy` には
   pnpm 11.22.0 以降が必要で、デプロイ手順でも同じデフォルトが使われるため、
   テンプレートではハッシュだけを指定し、`pnpm` は省略しています。nixpkgs が提供する
   `pnpm_11` が古い場合、`pnpmWorkspaceDeploy` は npm tarball から 11.22.0 を
   ビルドします。`pnpm` を上書きするのは、互換性のある別バージョンを使う場合だけに
   してください。`pnpmDepsHash` の代わりに `pnpmDeps` を渡すのは、ロックファイルに
   `importPnpmLock` などのカスタムフェッチャーが必要な場合だけです。このような
   バンドルでは、`pnpm-lock.json` と、アップストリームに存在する場合は
   `pnpm-workspace.json` を `package.nix` と同じディレクトリに同梱し、それぞれ
   `lockfileJson` と `workspaceJson` として渡します。また、
   `passthru.updateScript` を、バージョン更新のたびに両ファイルを再生成する
   `update.sh` に書き換えます。
4. 次を実行します。

   ```sh
   pnpm --filter <deployPackage> deploy \
     --prod \
     --config.node-linker=hoisted \
     --config.link-workspace-packages=true \
     "$out/lib"
   ```

`pnpm ... --legacy` は使用しないでください。注入されたワークスペースレイアウトが、
サポート対象のプロトコルです。デプロイ先は `$out/lib` です。ビルド出力をソースツリーに
コピーして戻さないでください。

`pnpm deploy --ignore-scripts` は、ソースのみのワークスペースパッケージをビルドしません。
選択したパッケージがそのようなワークスペースに依存している場合は、`preDeploy` で
ビルドし（例: `pnpm --workspace-concurrency=4 --config.ignore-workspace-cycles=true
-r build`）、`postNormalizeDeploy` でランタイムのエントリーポイントを検証してください。

アグリゲーターバンドルでは、`disableChildBundlePatches = true` を設定して、子の
`cordis.patch.yml` ファイルを空にし、`deployPackage` のみがローダーエントリーを
登録するようにします。

`postDeploy` は `pnpm deploy` の直後、ビルダーが出力レイアウトを正規化する前に
実行されます。`$deployPackagePath` にある最終パッケージを必要とする検査やクリーンアップには、
`postNormalizeDeploy` を使用してください。ビルダーは、共有の
`$out/lib/node_modules` ツリーをそのまま維持しながら、デプロイされたパッケージの
ファイルをそこへ移動します。

`src.hash` と `pnpmDepsHash` は、`nix build` が報告したハッシュで更新してください。
構成済みの `dsh` パッケージは、`installCheckPhase` の間に `dshBundleCheckHook` を
通じて管理対象のすべてのプロファイルを起動します。これを利用して、ローダーエントリー ID の
重複、無効なパッチ、インストールの peer のインポート不足、パッケージ解決の失敗を、実行前に
検出してください。対話型ターミナルのループ内にとどまるプロファイルでは、
`requiresTty = true` を設定できます。フックはこれらを擬似端末の下で実行し、
スモークウィンドウが生存していれば起動成功とみなします。dsh が
`skipping profile bundle` または `disabling profile plugin` を報告した場合も、
フックは失敗します。たとえば、バンドルの `engines.dsh` や
`@deepseek-ai/dsh-*` の peer 範囲が、固定されたランタイムを対象外としている場合です。
そのランタイムに対してバンドルを検証した後は、その式に `dshEngines = "<version>"` を
設定してください。ビルダーがこれを `engines.dsh` に書き込み、dsh は peer 範囲を
無視するようになります。

`buildDshBundle.fromPnpmWorkspace` は、`nodejs` と pnpm をランタイムクロージャから
自動的に除外します。ワークスペースバンドルがビルド中に `python3` を使用する場合は、
バンドルの式にある `disallowedReferences` に `python3` を追加してください。

## スタンドアロン npm バンドルの追加

ソースが pnpm ワークスペースのデプロイ対象ではない場合は、`buildDshBundle` を
使用してください。標準のインストールでは、パッケージディレクトリに
`package.json.name` を使用し、ランタイムペイロードには `npm pack` のファイル一覧を
使用します。

```nix
{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-runtime,
}:
buildDshBundle (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "example";
    repo = "example-bundle";
    rev = "0000000000000000000000000000000000000000";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  npmBuildScript = "build";

  meta = {
    description = "Example standalone DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

パッケージマニフェストでは、`cordis.patch.yml` とランタイムのビルド出力を npm
パッケージペイロードに含める必要があります。npm パッケージレイアウトで必要な
ランタイム出力を表現できない場合にのみ、`installPhase` を上書きしてください。
カスタムフェーズでは、パッケージを `$out/lib/node_modules` 以下に配置する必要があります。

```nix
{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-runtime,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";
  installation = dsh-runtime;

  src = fetchFromGitHub {
    owner = "example";
    repo = "example-bundle";
    rev = "0000000000000000000000000000000000000000";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/example-bundle"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml lib "$appDir/"

    runHook postInstall
  '';

  meta = {
    description = "Example standalone DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

パッケージに `pnpmDeps`、`fetchPnpmDeps`、`pnpmConfigHook`、または `pnpm_11` が
必要な場合は、pnpm ワークスペースのテンプレートと同様に、それらを関数引数へ追加して
ください。スコープ付きの `fetchPnpmDeps` はデフォルトでデプロイ用の pnpm を使うため、
フェッチまたはビルドだけを行うスタンドアロンバンドルでは、`pnpm = pnpm_11` を渡す
必要があります。`buildDshBundle` は pnpm をランタイムクロージャへ自動的に追加しないため、
`pnpm_11` を使用するときは `disallowedReferences` に入れたままにしてください。

## アップストリームワークスペースバンドルの追加

固定された `dsh-workspace` ソースからビルドするバンドルには、
`buildDshBundle.fromWorkspace` を使用してください。`dsh-workspace` は、
`dsh.bundle` を持つすべてのアップストリームマニフェストを検出し、そのパッケージと
プロダクションクロージャをデプロイします。正確な npm `packageName` を指定して、
デプロイ対象を選択してください。

```nix
{
  lib,
  buildDshBundle,
  dsh-runtime,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-workspace;
  pname = "example-workspace-bundle";
  packageName = "@deepseek-ai/example-workspace-bundle";
  installation = dsh-runtime;

  runtimeDeps = [ ];

  meta = {
    description = "Example upstream workspace DSH bundle";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromWorkspace` は、デプロイ結果全体を標準の
`$out/lib/node_modules/<packageName>` レイアウトへコピーし、`dsh-workspace` を
ランタイムクロージャの外に保ちます。

オプションの `artifacts` リストは、ビルド済み Web フロントエンドなど、npm パッケージに
属さない追加のワークスペース出力専用です。`runtimeDeps` は、`PATH` の先頭に追加する
必要がある実行可能ファイルにのみ使用してください。バンドルが所有する npm ペイロードは、
そのデプロイ済みクロージャ内に保持されます。

## リリースコホートからのクライアント peer

バンドルは、アップストリームが公開したクライアントパッケージに対してコンパイルしますが、
インストールにはこれらのパッケージが含まれていません。
`pnpm run release:pack --family dsh` は、それらの npm tarball と
`publish-order.txt` をリリースコホートとして出力します。

`pkgs.dsh.dshCohort`（ソース: `lib/dsh-cohort.nix`）は、このパックを公開します。

使用するコホートメンバー名は、このファイル内のローカルなリストであり、属性として
公開されません。コホートはビルド出力であるため、評価時に読み取るのではなく、
ファイル内で宣言します。

- `select [ ... ]`: バンドルが宣言済みメンバーから選択した項目を、スコープ付き npm 名として
  返します。宣言されていない名前を選択すると、評価が失敗します。
- `installPackages { dest ? "node_modules", names }`: `dest` 以下にある指定された
  パッケージを、公開された tarball の内容で置き換えます。
- `member name`: 1 つのメンバーを展開した tarball。`name` と `version` がワークスペースの
  リリースと一致することを検証します。
- `check`: `checks.dsh-cohort` として、宣言されたメンバーがパックまたは
  `publish-order.txt` に存在しない場合に失敗します。

バンドルは、コンパイル対象の peer を指定し、それらを出力に含めてはならない場合は
再び削除します。

```nix
let
  clientPackages = dshCohort.select [
    "dsh-client-ui-slots"
    "dsh-client-connection"
  ];
in
...
  preBuild = ''
    ${dshCohort.installPackages { names = clientPackages; }}
  '';

  postBuild = ''
    for clientPackage in ${lib.concatStringsSep " " clientPackages}; do
      rm -rf "node_modules/$clientPackage"
    done
  '';
```

## dsh-workspace のバージョン更新

ランタイムを更新すると、ビルドは正常に完了しても、dsh が実行時にバンドルをスキップする
ことがあります。固定バージョンを更新する前後で、次を実行してください。

- `scripts/dsh-bump-report.sh NEW_VERSION` は、固定されたソースと新しい
  アップストリームソースを比較します。比較対象は、削除されたパッケージとエクスポート、
  バンドル行、公式バンドルリスト、ビルド入力、ローカルワークスペースパッチの適用対象、
  および dsh が各バンドルを受け入れるかどうかです。自動更新ワークフローは、このレポートを
  dsh-workspace の PR に追加し、対応項目が列挙されている場合は自動マージを無効のままにします。
- `scripts/dsh-bundle-probe.sh --all` は、各バンドルをそれぞれ専用のプロファイルで
  起動し、dsh のバージョンチェックだけで失敗するバンドルと、実行時に失敗するバンドルを
  区別します。

CI はバンドルと併せて `bundleCompositions` もビルドするため、スキップされたバンドルが
あるとチェックは失敗します。
