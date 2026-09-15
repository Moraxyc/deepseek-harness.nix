{
  imports = [
    ./git-hooks.nix
    ./treefmt.nix
    ./shell.nix
    ./checks/bundle-helper.nix
    ./checks/cohort.nix
    ./checks/dsh-service.nix
    ./checks/merge-check.nix
  ];
}
