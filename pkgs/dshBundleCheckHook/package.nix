{
  lib,
  makeSetupHook,
  coreutils,
  curl,
  util-linux,
  unixtools,
  stdenv,
}:

makeSetupHook {
  name = "dsh-bundle-check-hook";
  # A hook sits in nativeBuildInputs, so its runtime tools propagate as
  # buildInputs to land in the consumer's PATH.
  propagatedBuildInputs = [
    coreutils
    (lib.getBin curl)
    util-linux
  ]
  # util-linux has no script(1) on darwin.
  ++ lib.optional stdenv.hostPlatform.isDarwin unixtools.script;
  meta = {
    description = "Boot managed dsh profiles during installCheck to catch bundle runtime errors";
    maintainers = with lib.maintainers; [ ];
    license = lib.licenses.mit;
  };
} ./hook.sh
