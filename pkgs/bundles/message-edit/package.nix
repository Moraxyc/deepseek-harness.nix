{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-message-edit";
  version = "0.2.3";

  src = fetchFromGitHub {
    owner = "Moeblack";
    repo = "dsh-message-edit";
    rev = "b78a167064ca612f1c400060d2bfc1dc9bc46436";
    hash = "sha256-ceP1nbyoA2oasNP4OIRN3O20MJXAorIRow9yUZXk/cM=";
  };
  dontPatch = true;
  npmDepsHash = "sha256-EXMwWYsck/wej6G0myADgNwOFOQZnt1l4dnkXC9T53o=";
  npmBuildScript = "build";
  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/dsh-message-edit"
    mkdir -p "$appDir"
    cp package.json index.mjs client.js client.js.map cordis.patch.yml README.md "$appDir"/

    runHook postInstall
  '';

  meta = {
    description = "Branch-based message editing, reroll, retry, and version timeline for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供分支式消息编辑、重掷、重试与版本时间线";
    homepage = "https://github.com/Moeblack/dsh-message-edit";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
