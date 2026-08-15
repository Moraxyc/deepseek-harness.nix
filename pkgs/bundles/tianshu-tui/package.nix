{
  lib,
  fetchFromGitHub,
  fetchurl,
  buildDshBundle,
  jq,
  nix-update-script,
  stdenvNoCC,
}:

let
  source = stdenvNoCC.mkDerivation {
    pname = "dsh-tianshu-tui-source";
    version = "0.1.2-rc.6";

    src = fetchFromGitHub {
      owner = "huiliyi37";
      repo = "dsh-tianshu-tui";
      tag = "v0.1.2-rc.6";
      hash = "sha256-hlaRYVKXiITXs44vDqfnXbXvEZYnPFEPGPQjZC93RVQ=";
    };

    nativeBuildInputs = [ jq ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -r . "$out/"
      chmod -R u+w "$out"

      jq 'del(.scripts, .dependencies, .devDependencies, .peerDependencies)' \
        "$out/package.json" > "$out/package.json.tmp"
      mv "$out/package.json.tmp" "$out/package.json"

      cat > "$out/package-lock.json" <<'JSON'
      {
        "name": "@huiliyi37/dsh-tianshu-tui",
        "version": "0.1.2-rc.6",
        "lockfileVersion": 3,
        "requires": true,
        "packages": {
          "": {
            "name": "@huiliyi37/dsh-tianshu-tui",
            "version": "0.1.2-rc.6"
          }
        }
      }
      JSON

      runHook postInstall
    '';
  };

  runtimeTarballs = [
    {
      name = "get-east-asian-width";
      src = fetchurl {
        url = "https://registry.npmjs.org/get-east-asian-width/-/get-east-asian-width-1.6.0.tgz";
        hash = "sha256-RFH1ji9aTvJ66LS6JbZL6X06hBPchhSkMhoQ1Bju5tc=";
      };
    }
    {
      name = "string-width";
      src = fetchurl {
        url = "https://registry.npmjs.org/string-width/-/string-width-8.2.2.tgz";
        hash = "sha256-uUMFu1IS3ez8bjjvg6lkJb3i/OQJLp/97smHhdlC4Ps=";
      };
    }
    {
      name = "strip-ansi";
      src = fetchurl {
        url = "https://registry.npmjs.org/strip-ansi/-/strip-ansi-7.2.0.tgz";
        hash = "sha256-L6Ad6GpQIu8ydzq7xOhKU6HF0x9aXL8D7SV18QQIVD8=";
      };
    }
    {
      name = "ansi-regex";
      src = fetchurl {
        url = "https://registry.npmjs.org/ansi-regex/-/ansi-regex-6.3.0.tgz";
        hash = "sha256-o3DFiEcDUhdiYBSsb84JShQg/fDQM6aMLPj6t34cZ4k=";
      };
    }
  ];
in
buildDshBundle (finalAttrs: {
  pname = "dsh-tianshu-tui";
  version = "0.1.2-rc.6";

  src = source;

  npmDepsHash = "sha256-krf4qTEeAIOo2IXf1yEfn7Vj1tDh51b1r9hnjBHpdFQ=";
  forceEmptyCache = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@huiliyi37/dsh-tianshu-tui"
    mkdir -p "$appDir"

    cp -r package.json cordis.patch.yml lib "$appDir/"

    ${lib.concatMapStringsSep "\n" (dep: ''
      mkdir -p "$appDir/node_modules/${dep.name}"
      tar -xzf ${dep.src} -C "$appDir/node_modules/${dep.name}" --strip-components=1
    '') runtimeTarballs}

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Interactive TUI layer for dsh with rendering, panels, and terminal controls";
    descriptions.zh-CN = "dsh 的交互式 TUI 层，提供渲染、面板与终端控制";
    homepage = "https://github.com/huiliyi37/dsh-tianshu-tui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
