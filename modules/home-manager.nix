{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.dsh;
  mkDshRuntime = import ../lib/mk-dsh-runtime.nix;
  profileArtifacts = cfg.package.passthru.mkProfileArtifacts {
    inherit (cfg) agentPresets defaultProfile;
    profiles = cfg.profiles;
    homePatch = cfg.patch;
  };
  runtimePackage = mkDshRuntime {
    package = cfg.package;
    bundles = profileArtifacts.runtimeBundles;
    profileSeeder =
      if cfg.profiles == { } && cfg.patch == null then null else profileArtifacts.seedProfiles;
    defaultProfile = profileArtifacts.validatedDefaultProfile;
  };
in
{
  imports = [
    ./shared-profile-options.nix
    ./home-manager-service.nix
  ];

  config = lib.mkIf cfg.enable {
    home.packages = [ runtimePackage ];

    home.sessionVariables = lib.mkIf (cfg.home != null) {
      DSH_HOME = cfg.home;
    };

    home.activation.dsh = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.optionalString (cfg.home != null) "DSH_HOME=${lib.escapeShellArg cfg.home} "
      + lib.getExe profileArtifacts.seedProfiles
    );
  };
}
