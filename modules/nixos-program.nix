{
  config,
  lib,
  ...
}:

{
  imports = [ ./shared-profile-options.nix ];

  config = lib.mkIf config.programs.dsh.enable {
    environment.systemPackages = [
      ((config.programs.dsh.package.withProfiles config.programs.dsh.profiles).override {
        defaultProfile = config.programs.dsh.defaultProfile;
      })
    ];
  };
}
