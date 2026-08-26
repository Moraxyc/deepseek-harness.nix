{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  esbuild,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-memory-evolve";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "csyangwen";
    repo = "dsh-memory-evolve";
    tag = "v26082401";
    hash = "sha256-GrQhQFXEevkw7jmgIEnFLLLFAp/GUJJXftMTTNssGTo=";
  };

  # The host half is authored JavaScript; rebuild the browser half from its
  # TypeScript source with the pinned Nix esbuild instead of using lib/client.js.
  dontConfigure = true;
  dontPatch = true;
  npmDeps = null;
  nativeBuildInputs = [ esbuild ];
  linkKernelNodeModules = dsh-kernel;

  buildPhase = ''
    runHook preBuild

    mkdir -p lib
    esbuild src/client/index.ts \
      --bundle \
      --format=cjs \
      --platform=browser \
      --target=es2022 \
      --outfile=lib/client.js \
      '--external:@deepseek-ai/*' \
      --external:cordis \
      --external:react \
      --external:react-dom \
      --external:react-dom/client \
      --external:react/jsx-runtime \
      --loader:.css=text \
      --banner:js="window.__ModuleLoader__.load({ id: 'dsh-memory-evolve', factory: (require) => { var module = { exports: {} }; var exports = module.exports;" \
      --footer:js="return module.exports; } });"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/${finalAttrs.pname}"
    mkdir -p "$appDir/scripts"
    cp package.json cordis.patch.yml "$appDir/"
    cp -r lib skills vendor "$appDir/"
    cp scripts/sync-worker.mjs "$appDir/scripts/"

    runHook postInstall
  '';

  meta = {
    description = "Layered long-term memory, skill evolution, TODOs, and session orchestration for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供分层长期记忆、技能进化、待办管理与会话编排";
    homepage = "https://github.com/csyangwen/dsh-memory-evolve";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
