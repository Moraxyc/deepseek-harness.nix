# Repository maintenance tools, exposed as `nix run .#tools.<name>`. Each tool sees
# only its declared inputs on PATH, so it behaves the same on every machine. Checks
# pass fakes for the external services nix and gh.
{
  pkgs,
  nix ? pkgs.nix,
  gh ? pkgs.gh,
}:
let
  tool =
    {
      name,
      description,
      runtimeInputs,
      text,
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs text;
      inheritPath = false;
      meta.description = description;
    };
in
rec {
  inherit (pkgs.dsh) generate-optional-bundles;

  dsh-bundle-probe = tool {
    name = "dsh-bundle-probe";
    description = "Boot every bundle in its own profile and classify it as ok, gate-only, or broken";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      gnugrep
      gnused
      jq
      nix
      dsh.dsh-profile-smoke
    ];
    text = builtins.readFile ./dsh-bundle-probe.sh;
  };

  dsh-bump-report = pkgs.dsh.dsh-bump-report.override { inherit nix; };

  publish-auto-updates = tool {
    name = "publish-auto-updates";
    description = "Publish validated auto-updates to main, or open a pull request for each one that cannot be";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      gnugrep
      jq
      gh
    ];
    text = builtins.readFile ./publish-auto-updates.sh;
  };

  fetchrix-prepare-dsh-workspace = tool {
    name = "fetchrix-prepare-dsh-workspace";
    description = "Fetchrix prepare hook for dsh-workspace";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      jq
      yq-go
      generate-optional-bundles
    ];
    text = builtins.readFile ../pkgs/dsh-workspace/fetchrix-prepare.sh;
  };

  fetchrix-prepare-dsh-desktop-unofficial = tool {
    name = "fetchrix-prepare-dsh-desktop-unofficial";
    description = "Fetchrix prepare hook for dsh-desktop-unofficial";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      yarn-berry_4.yarn-berry-fetcher
    ];
    text = ''
      mkdir -p .fetchrix
      awk -f ${../pkgs/dsh-desktop-unofficial/drop-file-entries.awk} yarn.lock > .fetchrix/yarn.lock
      yarn-berry-fetcher missing-hashes .fetchrix/yarn.lock > .fetchrix/missing-hashes.json
    '';
  };
}
