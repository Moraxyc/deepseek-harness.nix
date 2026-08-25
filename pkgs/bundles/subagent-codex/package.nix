{
  codexPackage ? null,
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  nodejs-slim,
  stdenv,
}:

let
  pnpmLock = dsh-workspace.pnpmDeps.lockfile;
  codexVersion =
    pnpmLock.importers."packages/subagent/subagent-codex".dependencies."@openai/codex".version;
  lockedPlatformPackages = pnpmLock.snapshots."@openai/codex@${codexVersion}".optionalDependencies;
  platformPackageFor =
    system:
    let
      hostPlatform = lib.systems.elaborate system;
    in
    if hostPlatform.node.platform == null || hostPlatform.node.arch == null then
      null
    else
      "@openai/codex-${with hostPlatform.node; "${platform}-${arch}"}";
  hasPlatformPackage =
    system:
    let
      packageName = platformPackageFor system;
    in
    packageName != null && builtins.hasAttr packageName lockedPlatformPackages;
  platformPackage =
    let
      system = stdenv.hostPlatform.system;
      packageName = platformPackageFor system;
    in
    if hasPlatformPackage system then
      packageName
    else
      throw "dsh-subagent-codex: pnpm lock has no platform package for ${system}";
  targetTriple = lib.replaceStrings [ "-gnu" ] [ "-musl" ] stdenv.hostPlatform.rust.rustcTarget;
  supportedPlatforms = lib.filter hasPlatformPackage (dsh-workspace.meta.platforms or [ ]);
in
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;

  pname = "dsh-subagent-codex";
  packageName = "@deepseek-ai/dsh-subagent-codex";
  linkKernelNodeModules = dsh-kernel;
  passthru.requiresTty = true;

  postInstall = lib.optionalString (codexPackage != null) ''
    codexBinRoot="$out/lib/node_modules/@deepseek-ai/dsh-subagent-codex/node_modules/${platformPackage}/vendor/${targetTriple}/bin"

    ln -sf ${lib.getExe codexPackage} "$codexBinRoot/codex"
    ln -sf ${lib.getExe' codexPackage "codex-code-mode-host"} "$codexBinRoot/codex-code-mode-host"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    providerRoot="$out/lib/node_modules/@deepseek-ai/dsh-subagent-codex"
    platformRoot="$providerRoot/node_modules/${platformPackage}"
    test -d "$platformRoot"
    ${lib.getExe nodejs-slim} "$providerRoot/node_modules/@openai/codex/bin/codex.js" --version >/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Codex subagent provider for dsh";
    descriptions.zh-CN = "dsh 的 Codex 子代理提供程序";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = with lib.licenses; [
      asl20
      mit
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.intersectLists (
      if codexPackage == null then
        supportedPlatforms
      else
        codexPackage.meta.platforms or supportedPlatforms
    ) supportedPlatforms;
  };
})
