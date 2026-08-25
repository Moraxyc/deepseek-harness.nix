{
  autoPatchelfHook,
  claudeCodePackage ? null,
  lib,
  buildDshBundle,
  dsh-kernel,
  dsh-workspace,
  stdenv,
}:

let
  pnpmLock = dsh-workspace.pnpmDeps.lockfile;
  claudeVersion =
    pnpmLock.importers."packages/subagent/subagent-claude-code".dependencies."@anthropic-ai/claude-agent-sdk".version;
  lockedPlatformPackages =
    pnpmLock.snapshots."@anthropic-ai/claude-agent-sdk@${claudeVersion}".optionalDependencies;
  platformPackageFor =
    system:
    let
      hostPlatform = lib.systems.elaborate system;
    in
    if hostPlatform.node.platform == null || hostPlatform.node.arch == null then
      null
    else
      "@anthropic-ai/claude-agent-sdk-${with hostPlatform.node; "${platform}-${arch}"}"
      + lib.optionalString hostPlatform.isMusl "-musl";
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
      throw "dsh-subagent-claude-code: pnpm lock has no platform package for ${system}";
  supportedPlatforms = lib.filter hasPlatformPackage (dsh-workspace.meta.platforms or [ ]);
in
buildDshBundle.fromWorkspace (_finalAttrs: {
  inherit dsh-kernel dsh-workspace;

  pname = "dsh-subagent-claude-code";
  packageName = "@deepseek-ai/dsh-subagent-claude-code";
  linkKernelNodeModules = dsh-kernel;
  passthru.requiresTty = true;

  nativeBuildInputs = lib.optionals (stdenv.hostPlatform.isLinux && claudeCodePackage == null) [
    autoPatchelfHook
  ];
  buildInputs = lib.optionals (stdenv.hostPlatform.isLinux && claudeCodePackage == null) [
    stdenv.cc.cc.lib
  ];

  postInstall = lib.optionalString (claudeCodePackage != null) ''
    ln -sf ${lib.getExe claudeCodePackage} "$out/lib/node_modules/@deepseek-ai/dsh-subagent-claude-code/node_modules/${platformPackage}/claude"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/lib/node_modules/@deepseek-ai/dsh-subagent-claude-code/node_modules/${platformPackage}/claude --version >/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Claude Code subagent provider for dsh";
    descriptions.zh-CN = "dsh 的 Claude Code 子代理提供程序";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = with lib.licenses; [
      mit
      unfree
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.intersectLists (
      if claudeCodePackage == null then
        supportedPlatforms
      else
        claudeCodePackage.meta.platforms or supportedPlatforms
    ) supportedPlatforms;
  };
})
