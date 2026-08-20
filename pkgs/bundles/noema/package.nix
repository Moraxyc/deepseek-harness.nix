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
  version = "0.1.0-rc.2-unstable-2026-08-19";
  deployPackage = "@zseven-w/dsh-noema";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-noema";
    rev = "3f2dc5aa43e5174cd69271729b9fc178bf8dd85a";
    hash = "sha256-7b0IDdT1cl4nRQN/sx5nhfvXaEkBnwdl3mBmW8QY+Ck=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-IgTpkTt5Js3abke85E8WMSWvuCP4yR8o2I/NqZMLPUM=";
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
