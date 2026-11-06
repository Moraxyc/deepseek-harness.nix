{
  lib,
  runCommand,
  dsh-runtime,
  nodejs-slim,
}:

# The Electron shell loads dsh from resources/host; point it at the shared
# installation instead of copying it.
runCommand "dsh-desktop-runtime-${dsh-runtime.version}"
  {
    inherit (dsh-runtime) version;
    meta = {
      description = "Desktop Host runtime backed by the shared dsh installation";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
    };
  }
  ''
    mkdir -p "$out"
    ln -s ${dsh-runtime}/node_modules "$out/node_modules"
    ln -s ${dsh-runtime}/node_modules/@deepseek-ai/dsh/package.json "$out/package.json"

    home="$TMPDIR/dsh-runtime-home"
    DSH_HOME="$home" ${lib.getExe nodejs-slim} --expose-internals \
      "$out/node_modules/@deepseek-ai/dsh/lib/bin.js" --version
    DSH_HOME="$home" ${lib.getExe nodejs-slim} --expose-internals \
      "$out/node_modules/@deepseek-ai/dsh/lib/bin.js" web --help >/dev/null
  ''
