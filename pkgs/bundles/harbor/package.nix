{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  jq,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-harbor";
  version = "0.1.0-rc.2";

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-harbor";
    rev = "d0609b89223fddfa3563ccf18c524b4c4094ff35";
    hash = "sha256-8TbHbMwWPyj8MqnvYBCFmzAZwkWIaR5xCtZaenHJbyc=";
  };

  # The upstream repository commits both the ESM host source and the generated
  # React module-loader payload. Its lockfile contains only development-time
  # tooling; the kernel supplies React and DSH client peers, while the pinned
  # workspace web runtime supplies the React DOM peer closure.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-Xxee0X2D5b/CQn6096AFjNvBULGerO0KXbP8/mq7JdY=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  disallowedReferences = [ dsh-workspace ];
  linkKernelNodeModules = dsh-kernel;

  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies, .peerDependenciesMeta)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cat > package-lock.json <<'JSON'
    {
      "name": "@zseven-w/dsh-harbor",
      "version": "${finalAttrs.version}",
      "lockfileVersion": 3,
      "requires": true,
      "packages": {
        "": {
          "name": "@zseven-w/dsh-harbor",
          "version": "${finalAttrs.version}"
        }
      }
    }
    JSON
  '';

  dontConfigure = true;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@zseven-w/dsh-harbor"
    mkdir -p "$appDir/node_modules/@deepseek-ai"
    cp -r package.json cordis.patch.yml src lib "$appDir/"

    # dsh-kernel provides React and the DSH client peers, but its CLI runtime
    # does not carry react-dom or the workspace-only ui-slots package. Keep
    # those web runtime peers local so the generated client has no unresolved
    # imports when this bundle is composed on its own.
    webRuntime="${dsh-workspace}/lib/dsh-workspace/runtime-bundles/@deepseek-ai/dsh-web-app/node_modules"
    cp -rL "$webRuntime/react-dom" "$webRuntime/scheduler" "$appDir/node_modules/"
    cp -rL \
      "${dsh-workspace}/lib/dsh-workspace/client-packages/@deepseek-ai/dsh-client-ui-slots" \
      "$appDir/node_modules/@deepseek-ai/dsh-client-ui-slots"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Read-only DSH plugin inventory with capability evidence, conflict detection, and change tracking";
    descriptions.zh-CN = "只读盘点 DSH 插件能力、证据、跨插件冲突与扫描变化";
    homepage = "https://github.com/ZSeven-W/dsh-harbor";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
