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
  pname = "dsh-approve-for-me";
  version = "0-unstable-2026-09-04";
  deployPackage = "dsh-approve-for-me";
  linkKernelNodeModules = dsh-kernel;

  src = fetchFromGitHub {
    owner = "timeance";
    repo = "dsh-approve-for-me";
    rev = "004d82dcbbeabf693b6289fd37a393ce061d4af8";
    hash = "sha256-gYQlUDjzWkzMfrAT4rhYikGeTFzJYRG3T5blMJpXRrw=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-F+FhDVB0LGsRGTIWzvDhOFLm/8i5uhrxbZ+ONYSCRC4=";
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
    description = "Rule-gated automatic approval for DeepSeek Harness sandbox escalations";
    descriptions.zh-CN = "为 DeepSeek Harness 沙箱提权提供规则分流的自动审批插件";
    homepage = "https://github.com/timeance/dsh-approve-for-me";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
