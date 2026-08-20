{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.dsh-service = pkgs.testers.runNixOSTest {
        name = "dsh-service";

        nodes.machine =
          { pkgs, ... }:
          {
            imports = [
              ../../../../modules/nixos-program.nix
              ../../../../modules/nixos-service.nix
            ];

            environment.etc."dsh-test.env".text = "DEEPSEEK_API_KEY=test-key\n";
            environment.systemPackages = with pkgs; [
              curl
              yq-go
            ];

            # The service composes its package from the profiles declared
            # under programs.dsh.
            # dshBundleCheckHook validates the composed profile at build
            # time, so this profile must be a real web profile and its patch
            # must remain a top-level YAML array.
            programs.dsh = {
              enable = true;
              home = "/var/lib/dsh/cli-home";
              patch = [
                {
                  id = "agent-default-model";
                  config = {
                    model = "deepseek-v4-flash";
                    provider = "deepseek-official";
                  };
                }
              ];
              profiles.web = {
                bundles = [ pkgs.dsh.bundles.web-app ];
                patch = ''
                  # served by programs.dsh.profiles
                  []
                '';
              };
            };

            services.dsh = {
              enable = true;
              environmentFile = "/etc/dsh-test.env";
              isolation.enable = true;
            };
          };

        testScript = ''
          machine.succeed(
            "set +u; . /etc/set-environment; set -u; test \"$DSH_HOME\" = /var/lib/dsh/cli-home; dsh --profile nix-web --version"
          )
          machine.succeed(
            "test -f /var/lib/dsh/cli-home/profiles/nix-web/cordis.patch.yml"
          )
          machine.succeed(
            "truncate -s 0 /var/lib/dsh/cli-home/cordis.patch.yml; set +u; . /etc/set-environment; set -u; dsh --profile nix-web --version; yq -e '.[0].id == \"agent-default-model\" and .[0].config.model == \"deepseek-v4-flash\" and .[0].config.provider == \"deepseek-official\"' /var/lib/dsh/cli-home/cordis.patch.yml"
          )
          machine.wait_for_unit("dsh-web.service")
          machine.succeed(
            "yq -e '.[0].id == \"agent-default-model\"' /var/lib/dsh/home/cordis.patch.yml"
          )
          machine.wait_until_succeeds(
            "grep -q 'served by programs.dsh.profiles' /var/lib/dsh/home/profiles/nix-web/cordis.patch.yml"
          )
          machine.wait_for_open_port(3080)
          machine.wait_until_succeeds(
            "journalctl -u dsh-web --no-pager | grep -q 'dsh web: http://127.0.0.1:3080'"
          )
          machine.wait_until_succeeds(
            "curl --fail --silent http://127.0.0.1:3080/ | grep -q '<title>DeepSeek Harness</title>'"
          )
        '';
      };
    };
}
