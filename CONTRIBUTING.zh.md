# 贡献指南

## 选择 bundle builder

按 bundle 来源选择 builder：

- `buildDshBundle`：独立 npm 源码，需自带 `installPhase`，并把构建产物放到
  `$out/lib/node_modules`。
- `buildDshBundle.fromPnpmWorkspace`：外部 pnpm monorepo，把选中的工作区
  包直接部署到 `$out/lib`。
- `buildDshBundle.fromWorkspace`：使用 `dsh-workspace` 已部署的上游包及其
  production 闭包。

所有 builder 执行同一套 bundle 校验：`$out/lib/node_modules` 中至少有一个
包声明 `dsh.bundle.patch`，且补丁文件存在于该包根目录下。

## 添加外部 pnpm workspace bundle

外部 monorepo bundle 使用 `buildDshBundle.fromPnpmWorkspace`。该 builder
管理受支持的 pnpm deploy 协议，并生成标准 `$out/lib` 布局。

bundle 目录名对应 flake 输出 `bundles.*`。上游包放到 `pkgs/bundles/` 时去掉
`dsh-` 前缀。例如 `dsh-ads` 对应 `pkgs/bundles/ads` 和 `bundles.ads`；
Nix 包的 `pname` 仍可保留上游名称。

最小模板：

```nix
{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  pnpmConfigHook,
  pnpm_11,
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

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postDeploy = ''
    # Optional bundle-specific layout fixes.
  '';

  meta = {
    description = "Example DSH bundle";
    homepage = "https://github.com/example/example-bundle";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromPnpmWorkspace` 在 bundle derivation 中执行以下步骤：

1. 当 `stripPrepareScripts = true` 时，先移除 workspace 的 `prepare` 脚本，
   让 pnpm 在部署前跳过源码包重建。该方式同时支持 `packages/*` 多包
   workspace 和只声明 `packages: ["."]` 的单包 workspace。
2. 运行 `pnpm config set --location=project inject-workspace-packages true`。
3. 如果 nixpkgs 提供的 `pnpm_11` 较旧，DSH package scope 会提供 pnpm 11.22.0，
   确保依赖获取和 workspace deploy 使用同一个兼容版本，同时不修改调用方的
   package set。
4. 运行：

   ```sh
   pnpm --filter <deployPackage> deploy \
     --prod \
     --config.node-linker=hoisted \
     --config.link-workspace-packages=true \
     "$out/lib"
   ```

deploy 命令使用上述参数和注入式 workspace 布局，这是受支持的协议。部署目标
固定为 `$out/lib`，构建产物保留在该目录下。

聚合 bundle 可设置 `disableChildBundlePatches = true`，让子包
`cordis.patch.yml` 清空，仅由 `deployPackage` 注册 loader 条目。包需要 kernel
peer（如 `@deepseek-ai/dsh-settings`）时，传 `linkKernelNodeModules =
dsh-kernel`。helper 先移除 bundle 输出中 kernel 持有的包（包括 kernel 提供的
`@deepseek-ai/*`），清理悬空的 `.bin` 链接，再把 kernel 的 `node_modules`
树链接到 `$out/lib/node_modules` 下的每个包。这样 kernel 保持唯一运行时
提供者。如果 bundle 想保留与 kernel 同名包的自身版本，把该包列入
`linkKernelNodeModulesKeep`。

`postDeploy` 可使用 `$deployPackagePath`，它指向 `$out/lib/node_modules` 内的
已部署包。常见的聚合布局调整：

```sh
rm -rf "$deployPackagePath"
mkdir -p "$deployPackagePath"
mv \
  "$out/lib/package.json" \
  "$out/lib/cordis.patch.yml" \
  "$out/lib/lib" \
  "$deployPackagePath/"
```

更新 `src.hash` 和 `pnpmDeps.hash` 时，以 `nix build` 报告的哈希为准。
组合后的 `dsh` 在 `installCheckPhase` 通过 `dshBundleCheckHook` 启动每个
托管 profile，可提前发现重复 loader ID、无效补丁、缺失 kernel peer 和包解析
失败。交互式终端循环 profile 可设置 `requiresTty = true`；hook 会在伪终端下
运行，并视存活 smoke 窗口为启动成功。

`buildDshBundle.fromPnpmWorkspace` 会把 `nodejs` 和 pnpm 排除在运行时闭包
之外。如果 workspace bundle 构建期间使用 `python3`，把 `python3` 加入 bundle
表达式的 `disallowedReferences`。

## 添加独立 npm bundle

源码属于 pnpm workspace 部署目标时使用 `buildDshBundle.fromPnpmWorkspace`，
其他情况使用 `buildDshBundle`。独立 bundle 的 derivation 需要自己填充
`$out/lib/node_modules`，把包 manifest、补丁文件、运行时代码和 bundle 专属
依赖复制到包根目录。kernel 持有的包由 `linkKernelNodeModules` 提供：

```nix
{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "example-bundle";
  version = "0.1.0";
  linkKernelNodeModules = dsh-kernel;

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

包需要 `pnpmDeps`、`fetchPnpmDeps`、`pnpmConfigHook` 或 `pnpm_11` 时，在
函数参数中补齐。运行时闭包默认不含 pnpm；用到 `pnpm_11` 时，把它写进
`disallowedReferences`。

## 添加上游 workspace bundle

从固定 `dsh-workspace` 源码构建的 bundle 使用 `buildDshBundle.fromWorkspace`。
`dsh-workspace` 会发现所有声明 `dsh.bundle` 的上游 manifest，并部署对应包及其
production 闭包。用准确的 npm `packageName` 选择部署结果：

```nix
{
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
}:
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;
  pname = "example-workspace-bundle";
  packageName = "@deepseek-ai/example-workspace-bundle";
  linkKernelNodeModules = dsh-kernel;

  runtimeDeps = [ ];

  meta = {
    description = "Example upstream workspace DSH bundle";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

`fromWorkspace` 把完整部署结果复制到标准
`$out/lib/node_modules/<packageName>` 布局，并把 `dsh-workspace` 排除在运行时
闭包之外。设置 `linkKernelNodeModules = dsh-kernel` 可去重 kernel 持有的包，
并满足 bundle 的 kernel peer。若需保留与 kernel 同名的 bundle 本地版本，使用
`linkKernelNodeModulesKeep`。

可选的 `artifacts` 只用于 npm 包之外的额外 workspace 产物，例如构建后的 web
frontend。只有必须预置到 `PATH` 的可执行程序才放入 `runtimeDeps`；Bundle 持有
的 npm payload 保留在其部署闭包内。
