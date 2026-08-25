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
buildDshBundle (finalAttrs: {
  pname = "dsh-opentelemetry";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "loongsuite";
    repo = "dsh-plugin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-2qHSagsOHco8a7whBv/76otC8CouEVl27MiQwE2MhQ4=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = lib.fakeHash;
  };

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";
  nativeBuildInputs = [ pnpm_11 ];
  disallowedReferences = [ pnpm_11 ];

  linkKernelNodeModules = dsh-kernel;
  linkKernelNodeModulesKeep = [
    "@opentelemetry/api-logs"
    "@opentelemetry/core"
    "@opentelemetry/exporter-metrics-otlp-proto"
    "@opentelemetry/exporter-trace-otlp-proto"
    "@opentelemetry/otlp-exporter-base"
    "@opentelemetry/otlp-transformer"
    "@opentelemetry/sdk-logs"
    "@opentelemetry/sdk-metrics"
    "@opentelemetry/sdk-trace"
    "@opentelemetry/sdk-trace-base"
  ];

  installPhase = ''
    runHook preInstall

    pnpm install --prod --config.node-linker=hoisted --ignore-scripts --offline --frozen-lockfile

    appDir="$out/lib/node_modules/@loongsuite/dsh-plugin"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml README.md README.zh-CN.md LICENSE dist "$appDir/"
    cp -r node_modules "$appDir/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "OpenTelemetry tracing and metrics for DeepSeek Harness";
    descriptions.zh-CN = "为 DeepSeek Harness 提供 OpenTelemetry 链路追踪与指标导出";
    homepage = "https://github.com/loongsuite/dsh-plugin";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
