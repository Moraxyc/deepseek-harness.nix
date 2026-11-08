{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dshCohort,
  dsh-runtime,
  jq,
  nix-update-script,
  writers,
}:
let
  clientPackages = dshCohort.select [ "dsh-client-ui-slots" ];
in
buildDshBundle (finalAttrs: {
  pname = "dsh-harbor";
  version = "0.1.0-rc.4-unstable-2026-11-08";

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-harbor";
    rev = "b939daee185d25da206109023748801f983371ed";
    hash = "sha256-hq48YnnnZpzM/Q/LxcBiQLQW25VHS5ovnPtmrz/SumU=";
  };

  # The upstream repository commits both the ESM host source and the generated
  # React module-loader payload, and its lockfile lists development-time tooling
  # only. The payload's React and React DOM imports resolve against the web
  # frontend's module-loader seeds, and the installation supplies the host peers.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-z/a4AvPx45RAnsJcHdWuDP17JY0LOaGH25PeprUx1kI=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  installation = dsh-runtime;

  postPatch = ''
    jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies, .peerDependenciesMeta)' \
      package.json > package.json.tmp
    mv package.json.tmp package.json

    cp ${writers.writeJSON "package-lock.json" finalAttrs.passthru.packageLock} package-lock.json
  '';

  dontConfigure = true;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@zseven-w/dsh-harbor"
    mkdir -p "$appDir"
    cp -r package.json cordis.patch.yml src lib "$appDir/"

    # The client manifest injects the client-only ui-slots package, which no
    # other bundle in this closure carries.
    ${dshCohort.installPackages {
      dest = "$appDir/node_modules";
      names = clientPackages;
    }}

    runHook postInstall
  '';

  passthru = {
    requiresWeb = true;
    packageLock = {
      name = "@zseven-w/dsh-harbor";
      version = finalAttrs.version;
      lockfileVersion = 3;
      requires = true;
      packages."" = {
        name = "@zseven-w/dsh-harbor";
        version = finalAttrs.version;
      };
    };

    updateScript = nix-update-script {
      extraArgs = [
        "--flake"
        "--version=branch"
      ];
    };
  };

  meta = {
    description = "Read-only DSH plugin inventory with capability evidence, conflict detection, and change tracking";
    descriptions.zh-CN = "只读盘点 DSH 插件能力、证据、跨插件冲突与扫描变化";
    descriptions.ja = "DSH プラグインを読み取り専用で棚卸しし、機能の根拠、プラグイン間の競合、スキャン間の変化を確認するツール";
    homepage = "https://github.com/ZSeven-W/dsh-harbor";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
