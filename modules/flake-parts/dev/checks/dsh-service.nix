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
            imports = [ ../../../../modules/nixos-service.nix ];

            environment.etc."dsh-test.env".text = "DEEPSEEK_API_KEY=test-key\n";
            environment.systemPackages = with pkgs; [
              curl
            ];

            # The service composes its package from the profiles declared
            # under programs.dsh.
            # dshBundleCheckHook validates the composed profile at build
            # time, so this profile must be a real web profile and its patch
            # must remain a top-level YAML array.
            programs.dsh.profiles.web = {
              bundles = [ pkgs.dsh.bundles.web-app ];
              patch = ''
                # served by programs.dsh.profiles
                []
              '';
            };

            services.dsh = {
              enable = true;
              environmentFile = "/etc/dsh-test.env";
            };
          };

        testScript = ''
          machine.wait_for_unit("dsh-web.service")
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
