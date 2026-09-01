{
  lib,
  fetchFromGitHub,
  buildDshBundle,
  dsh-kernel,
  nix-update-script,
}:
buildDshBundle (finalAttrs: {
  pname = "billion-context-dsh";
  version = "0.2.16";

  src = fetchFromGitHub {
    owner = "Tyan66666";
    repo = "billion-context-dsh";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Y0jUSft9GrWi8oFRAXs9w5OCO1MviQviiYEYqyPVqcE=";
  };

  npmDepsHash = "sha256-n0MJrkM82TFRN1lHqN+PWbtKfRy6xPpxzzfdvy4ydos=";
  npmBuildScript = "build";

  linkKernelNodeModules = dsh-kernel;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/${finalAttrs.pname}"
    mkdir -p "$appDir"
    cp -r LICENSE README.md README.en.md cordis.patch.yml dist package.json "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Model-driven active context pruning and compaction tools for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供模型驱动的主动上下文剪枝与压缩工具";
    homepage = "https://github.com/Tyan66666/billion-context-dsh";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
