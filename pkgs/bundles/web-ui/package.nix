{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  jq,
  buildDshBundle,
  dsh-kernel,
  pnpmConfigHook,
  pnpm_11,
}:
buildDshBundle (finalAttrs: {
  pname = "dsh-web-ui";
  version = "0.1.12";

  src = fetchFromGitHub {
    owner = "zhu1090093659";
    repo = "dsh-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-WqI/tyYPv+h/7fQbkDF7nYcnEMGzA9gF8iedEr2K/C8=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-j3F57Jl+AC6ZCxeFik08vsztOZOXJoDrBD5mno1LNqY=";
  };

  nativeBuildInputs = [
    jq
    pnpm_11
  ];

  npmDeps = null;
  npmConfigHook = pnpmConfigHook;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    find packages -name package.json -print0 \
      | xargs -0 -n1 sh -c '
          jq "del(.scripts.prepare)" "$0" > "$0.tmp"
          mv "$0.tmp" "$0"
        '

    pnpm config set --location=project inject-workspace-packages true
    pnpm --filter @linxin666/dsh-web-ui-all deploy \
      --prod \
      --config.node-linker=hoisted \
      --config.link-workspace-packages=true \
      "$out/lib"

    # dsh-web-ui-all aggregates every child plugin row; keep child patches
    # inert so the bundle does not install duplicate loader entries.
    for patch in "$out"/lib/node_modules/@linxin666/*/cordis.patch.yml; do
      pkgName=$(basename "$(dirname "$patch")")
      [ "$pkgName" = "dsh-web-ui-all" ] && continue
      printf '[]\n' > "$patch"
    done

    aggregatorDir="$out/lib/node_modules/@linxin666/dsh-web-ui-all"
    rm -rf "$aggregatorDir"
    mkdir -p "$aggregatorDir"
    mv \
      "$out/lib/package.json" \
      "$out/lib/cordis.patch.yml" \
      "$out/lib/lib" \
      "$aggregatorDir/"

    # The web-ui packages expect dsh kernel peers to resolve from the composed
    # application node_modules tree.
    for pkgDir in "$out"/lib/node_modules/@linxin666/*; do
      ln -s "${dsh-kernel}/lib/deepseek-harness/node_modules" "$pkgDir/node_modules"
    done

    # Prune
    find "$out/lib/node_modules" -type f -path '*/build/*' ! -name '*.node' -delete
    find "$out/lib/node_modules" -depth -type d -empty -delete

    runHook postInstall
  '';

  disallowedReferences = [ pnpm_11 ];

  meta = {
    description = "DSH web UI plugin and skin collection";
    homepage = "https://github.com/zhu1090093659/dsh-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
