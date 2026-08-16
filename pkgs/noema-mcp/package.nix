{
  lib,
  fetchFromGitHub,
  rustPlatform,
  git,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "noema-mcp";
  version = "0-unstable-2026-08-14";
  nativeBuildInputs = [ git ];

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "noema";
    rev = "92f558385ad17f9399380df212c492d3ee82d5f0";
    hash = "sha256-X1ZRSc+jEnsYil4gMrxyyJIv3qHJRapLIXVkrlYGR04=";
  };

  cargoHash = "sha256-F39dYA/T84Ze3tI0Xo0qpovap1FMCX4f0LpUvKut4jU=";
  cargoBuildFlags = [
    "--package"
    "noema-mcp"
  ];
  cargoTestFlags = [
    "--package"
    "noema-mcp"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Noema MCP stdio server used by the DSH noema memory plugin";
    descriptions.zh-CN = "DSH Noema 记忆插件使用的 MCP stdio 服务端";
    homepage = "https://github.com/ZSeven-W/noema";
    license = lib.licenses.mit;
    mainProgram = "noema-mcp";
    platforms = lib.platforms.unix;
  };
})
