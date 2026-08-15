{
  config,
  lib,
  ...
}:
let
  composed = (config.programs.dsh.package.withProfiles config.programs.dsh.profiles).override {
    defaultProfile = config.programs.dsh.defaultProfile;
  };
in
{
  imports = [ ./shared-profile-options.nix ];

  config = lib.mkIf config.programs.dsh.enable {
    home.packages = [ composed ];

    home.activation.dsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.getExe composed.passthru.seedProfiles}
    '';
  };
}
