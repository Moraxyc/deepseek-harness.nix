{
  lib,
  makeSetupHook,
  coreutils,
  curl,
  util-linux,
}:

makeSetupHook {
  name = "dsh-bundle-check-hook";
  propagatedNativeBuildInputs = [
    coreutils
    (lib.getBin curl)
    util-linux
  ];
  meta = {
    description = "Boot managed dsh profiles during installCheck to catch bundle runtime errors";
    maintainers = with lib.maintainers; [ ];
    license = lib.licenses.mit;
  };
} ./hook.sh
