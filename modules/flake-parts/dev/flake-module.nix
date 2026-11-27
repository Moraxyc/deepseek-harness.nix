{
  imports = [
    ./git-hooks.nix
    ./treefmt.nix
    ./shell.nix
    ./checks/bundle-helper.nix
    ./checks/cohort.nix
    ./checks/dsh-profile-smoke.nix
    ./checks/dsh-service.nix
    ./checks/external-bundles.nix
    ./checks/fetchrix.nix
    ./checks/package-ci.nix
    ./checks/optional-bundles.nix
    ./checks/runtime-importer.nix
  ];
}
