{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildDshBundle,
  dshCohort,
  dsh-kernel,
  jq,
  nix-update-script,
  writers,
}:
let
  clientPackages = dshCohort.select [ "dsh-client-ui-slots" ];
in
buildDshBundle (finalAttrs: {
  pname = "dsh-harbor";
  version = "0.1.0-rc.4-unstable-2026-11-05";

  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "dsh-harbor";
    rev = "95af1d07ad0d0e2f35776c68ba06693de6f5ae2a";
    hash = "sha256-m3bR80Ogmw5GZw2NaqwtU/jyregl2OhpfX37ES3wzec=";
  };

  # The upstream repository commits both the ESM host source and the generated
  # React module-loader payload, and its lockfile lists development-time tooling
  # only. The payload's React and React DOM imports resolve against the web
  # frontend's module-loader seeds, and the kernel supplies the host peers.
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = "sha256-xt2G7D5KvB4cfnnDCfqPUKo1wyQE9/eW6EZ/C18Dni4=";
    forceEmptyCache = true;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [ jq ];
  linkKernelNodeModules = dsh-kernel;

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
