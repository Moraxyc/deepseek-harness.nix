{
  baseBundle,
  formats,
  lib,
  linkFarm,
  writeShellApplication,
  writeText,
}:

{
  makeProfileTemplates =
    { profiles }:
    linkFarm "deepseek-harness-profiles" (
      lib.concatMapAttrs (name: profile: {
        "${name}/package.json" =
          (formats.json { }).generate
            "${lib.strings.sanitizeDerivationName "dsh-profile-${name}"}-package.json"
            {
              name = "dsh-profile-${name}";
              private = true;
              dependencies = { };
              dsh.profile.bundles = lib.unique (
                baseBundle.passthru.dshBundles
                ++ lib.concatMap (
                  bundle:
                  bundle.passthru.dshBundles or (throw ''
                    dsh.withProfiles: ${bundle.pname or bundle.name} has no passthru.dshBundles; it is not a dsh bundle package
                  '')
                ) profile.bundles
              );
            };
        "${name}/cordis.patch.yml" =
          writeText "${lib.strings.sanitizeDerivationName "dsh-profile-${name}"}-cordis.patch.yml"
            (profile.patch or "[]");
        "${name}/pnpm-workspace.yaml" =
          (formats.json { }).generate
            "${lib.strings.sanitizeDerivationName "dsh-profile-${name}"}-pnpm-workspace.yaml"
            {
              packages = [ "." ];
              nodeLinker = "hoisted";
              autoInstallPeers = false;
            };
      }) profiles
    );

  makeProfileSeeder =
    {
      coreutils,
      profileTemplates,
    }:
    writeShellApplication {
      name = "dsh-seed-profiles";
      runtimeInputs = [ coreutils ];
      inheritPath = false;
      text = ''
        home=''${DSH_HOME:-''${HOME:+$HOME/.dsh}}
        [ -n "$home" ] || exit 0

        mkdir -p "$home/profiles"
        cp \
          --dereference \
          --no-clobber \
          --no-preserve=mode \
          --recursive \
          ${lib.escapeShellArg "${profileTemplates}/."} \
          "$home/profiles"
      '';
    };
}
