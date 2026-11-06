# Helpers for the pkgs.dsh scope. The overlay is the only importer: packages,
# modules, and checks receive these through the scope.
{ lib }:
let
  # Call a helper with the arguments it names, without makeOverridable, so
  # helpers that return functions or attribute sets stay plain.
  autoCall =
    scope: path:
    let
      f = import path;
    in
    f (builtins.intersectAttrs (lib.functionArgs f) scope);
in
{
  # Scope members. `pkgs` is nixpkgs; `self` is the scope.
  scope =
    pkgs: self:
    let
      pnpm = import ./pnpm.nix {
        inherit lib;
        inherit (pkgs) fetchPnpmDeps pnpm_11;
      };
      call = autoCall (pkgs // pnpm // self);
    in
    pnpm
    // {
      buildDshBundle = call ./mk-dsh-bundle.nix;
      catalog = import ./catalog.nix {
        inherit lib;
        scope = self;
      };
      copyTree = call ./copy-tree.nix;
      dshCohort = call ./dsh-cohort.nix;
      mkDsh = import ./mk-dsh.nix;
      mkDshDesktop = call ./mk-dsh-desktop.nix;
      mkDshRuntime = import ./mk-dsh-runtime.nix;
      nodeModulesPrune = call ./node-modules-prune.nix;
      removedBundles = import ./removed-bundles.nix;
      webMaskableIcons = call ./web-maskable-icons.nix;
    };

  # Bundles the installation carries, generated from optional-bundles.json.
  optionalBundles = pkgs: self: autoCall (pkgs // self) ./dsh-optional-bundles.nix;
}
