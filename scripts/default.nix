# Repository maintenance tools, exposed as `nix run .#tools.<name>`. Each tool sees
# only its runtimeInputs on PATH, so it behaves the same on every machine. Checks
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
  generate-optional-bundles = tool {
    name = "generate-optional-bundles";
    description = "Generate optional-bundles.json from an upstream DeepSeek Harness source tree";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      findutils
      gawk
      gnugrep
      gnused
      jq
    ];
    text = builtins.readFile ./generate-optional-bundles.sh;
  };

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

  inherit (pkgs.dsh) dsh-bump-report;

  select-package-ci-attrs = tool {
    name = "select-package-ci-attrs";
    description = "Print the package attrs CI builds for the changes since a base ref";
    runtimeInputs = with pkgs; [
      gitMinimal
      jq
      nix
    ];
    text = builtins.readFile ./select-package-ci-attrs.sh;
  };

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

  update-dsh-engines = tool {
    name = "update-dsh-engines";
    description = "Raise each bundle's dshEngines grant to the pinned workspace version when its composition still boots";
    runtimeInputs = with pkgs; [
      ast-grep
      gitMinimal
      nodejs-slim
      nix
    ];
    text = ''
      exec node ${./update-dsh-engines.mjs} "$@"
    '';
  };

  fetchrix-prepare-dsh-workspace = tool {
    name = "fetchrix-prepare-dsh-workspace";
    description = "Fetchrix prepare hook for dsh-workspace";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      jq
      generate-optional-bundles
    ];
    text = builtins.readFile ../pkgs/dsh-workspace/fetchrix-prepare.sh;
  };

  fetchrix-prepare-subscriptions = tool {
    name = "fetchrix-prepare-subscriptions";
    description = "Fetchrix prepare hook for bundles.subscriptions";
    runtimeInputs = [ pkgs.yq-go ];
    text = ''
      yq -i --from-file ${../pkgs/bundles/subscriptions/drop-dev-links.yq} pnpm-lock.yaml
    '';
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
