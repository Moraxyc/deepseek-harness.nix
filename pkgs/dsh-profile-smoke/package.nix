{
  lib,
  stdenv,
  coreutils,
  curl,
  gnugrep,
  gnused,
  unixtools,
  util-linux,
  writeShellApplication,
}:

writeShellApplication {
  name = "dsh-profile-smoke";
  inheritPath = false;
  runtimeInputs = [
    coreutils
    curl
    gnugrep
    gnused
  ]
  # script(1): util-linux on Linux, the BSD one on Darwin.
  ++ (if stdenv.hostPlatform.isDarwin then [ unixtools.script ] else [ util-linux ]);
  text = builtins.readFile ./dsh-profile-smoke.sh;
  meta = {
    description = "Boot a dsh profile and fail if it drops a bundle or plugin row";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
