{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
  nix-update-script,
}:
buildDshBundle.fromPnpmWorkspace (finalAttrs: {
  pname = "dsh-noema";
  version = "0-unstable-2026-08-16";
  deployPackage = "@zseven-w/dsh-noema";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-noema";
    rev = "acfb4cd58c9486412fb3bfc9e978eae66e04e5a7";
    hash = "sha256-SNUSPMPN65uOjSDxyFxJeItMyUnbMXhIzlTrLXp7yO0=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-1ctfEcSAw4GoNVcBxCSwpfEVy8F+lQ9/qbFGaqQverM=";
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  postDeploy = ''
    rm -rf "$deployPackagePath"
    mkdir -p "$deployPackagePath"
    for entry in "$out"/lib/*; do
      case "$(basename "$entry")" in
        node_modules)
          continue
          ;;
      esac
      mv "$entry" "$deployPackagePath/"
    done
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Noema long-term memory plugin for DSH with recall tools and a settings page";
    descriptions.zh-CN = "DSH 的 Noema 长期记忆插件，提供召回工具与设置页";
    homepage = "https://github.com/ZSeven-W/dsh-noema";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
