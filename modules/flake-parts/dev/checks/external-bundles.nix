{ ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      composed = pkgs.dsh.dsh.withProfiles {
        mixed.bundles = b: [
          "@scope/first@^1.2.0"
          b.tui
          "second@github:me/second#v2"
          "third"
        ];
      };
      template = "${composed.passthru.profileTemplates}/nix-mixed";
    in
    {
      checks.dsh-external-bundles =
        pkgs.runCommand "dsh-external-bundles-check"
          {
            nativeBuildInputs = [ pkgs.jq ];
          }
          ''
            jq -e '
              .dependencies["@scope/first"] == "^1.2.0"
              and .dependencies.second == "github:me/second#v2"
              and .dependencies.third == "latest"
              and .dsh.profile.bundles == [
                "@deepseek-ai/dsh-base",
                "@deepseek-harness-tui/dsh-tui",
                "@scope/first",
                "second",
                "third"
              ]
            ' ${template}/package.json >/dev/null

            printf '%s\t%s\n' @scope/first '^1.2.0' second 'github:me/second#v2' third latest \
              | cmp - ${template}/.nix-external

            touch "$out"
          '';
    };
}
