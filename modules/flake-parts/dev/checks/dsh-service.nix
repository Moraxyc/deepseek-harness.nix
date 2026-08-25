{ lib, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      codexPackage = "@deepseek-ai/dsh-subagent-codex";
      claudePackage = "@deepseek-ai/dsh-subagent-claude-code";
      providerPackages = [
        codexPackage
        claudePackage
      ];
      testCodexPackage = pkgs.symlinkJoin {
        name = "dsh-test-codex";
        paths = [
          (pkgs.writeShellApplication {
            name = "codex";
            text = "printf '%s\\n' 'codex-cli dsh-test-override'";
          })
          (pkgs.writeShellApplication {
            name = "codex-code-mode-host";
            text = "printf '%s\\n' 'dsh-test-code-mode-host'";
          })
        ];
        meta = {
          mainProgram = "codex";
          platforms = lib.platforms.all;
        };
      };
      testClaudeCodePackage = pkgs.writeShellApplication {
        name = "claude";
        text = "printf '%s\\n' 'dsh-test-claude-code-override'";
        meta.platforms = lib.platforms.all;
      };
      providerProfile =
        providers:
        pkgs.dsh.dsh.override {
          defaultBundles = [ ];
          profiles.web.bundles = [ pkgs.dsh.bundles.web-app ] ++ providers;
        };
      checkProviderProfile =
        {
          name,
          providers,
          present,
          absent,
        }:
        let
          package = providerProfile providers;
        in
        pkgs.runCommand "dsh-provider-${name}-composition"
          {
            nativeBuildInputs = [ pkgs.jq ];
          }
          ''
            app="${package}/lib/deepseek-harness"
            ${lib.concatMapStringsSep "\n" (provider: ''
              if ! jq -e --arg provider ${lib.escapeShellArg provider} \
                '.dependencies | has($provider)' "$app/package.json" >/dev/null; then
                printf 'dsh composition is missing provider dependency: %s\n' \
                  ${lib.escapeShellArg provider} >&2
                exit 1
              fi
              [ -d "$app/node_modules/${provider}" ] || {
                printf 'dsh composition is missing provider package: %s\n' \
                  ${lib.escapeShellArg provider} >&2
                exit 1
              }
            '') present}
            ${lib.concatMapStringsSep "\n" (provider: ''
              if jq -e --arg provider ${lib.escapeShellArg provider} \
                '.dependencies | has($provider)' "$app/package.json" >/dev/null; then
                printf 'dsh composition contains unselected provider dependency: %s\n' \
                  ${lib.escapeShellArg provider} >&2
                exit 1
              fi
              if [ -e "$app/node_modules/${provider}" ] || [ -L "$app/node_modules/${provider}" ]; then
                printf 'dsh composition contains unselected provider package: %s\n' \
                  ${lib.escapeShellArg provider} >&2
                exit 1
              fi
            '') absent}
            touch "$out"
          '';
      codexPlatformPackage = with pkgs.stdenv.hostPlatform.node; "@openai/codex-${platform}-${arch}";
      claudePlatformPackage =
        with pkgs.stdenv.hostPlatform;
        "@anthropic-ai/claude-agent-sdk-${node.platform}-${node.arch}" + lib.optionalString isMusl "-musl";
    in
    {
      checks = {
        dsh-kernel-provider-isolation = pkgs.runCommand "dsh-kernel-provider-isolation" { } ''
          kernelNodeModules="${pkgs.dsh.dsh-kernel}/lib/deepseek-harness/node_modules"
          [ -d "$kernelNodeModules/@deepseek-ai/dsh-app-boot" ] || {
            printf 'dsh kernel is missing its runtime sentinel\n' >&2
            exit 1
          }
          for package in \
            "@deepseek-ai/dsh-subagent-codex" \
            "@deepseek-ai/dsh-subagent-claude-code" \
            "@openai/codex" \
            "${codexPlatformPackage}" \
            "@anthropic-ai/claude-agent-sdk" \
            "${claudePlatformPackage}"
          do
            if [ -e "$kernelNodeModules/$package" ] || [ -L "$kernelNodeModules/$package" ]; then
              printf 'dsh kernel contains optional provider package: %s\n' "$package" >&2
              exit 1
            fi
          done
          touch "$out"
        '';

        dsh-provider-codex = checkProviderProfile {
          name = "codex";
          providers = [
            (pkgs.dsh.bundles.subagent-codex.override {
              codexPackage = testCodexPackage;
            })
          ];
          present = [ codexPackage ];
          absent = [ claudePackage ];
        };

        dsh-provider-claude-code = checkProviderProfile {
          name = "claude-code";
          providers = [
            (pkgs.dsh.bundles.subagent-claude-code.override {
              claudeCodePackage = testClaudeCodePackage;
            })
          ];
          present = [ claudePackage ];
          absent = [ codexPackage ];
        };

        dsh-provider-coexistence = checkProviderProfile {
          name = "coexistence";
          providers = [
            pkgs.dsh.bundles.subagent-codex
            pkgs.dsh.bundles.subagent-claude-code
          ];
          present = providerPackages;
          absent = [ ];
        };

        dsh-service = pkgs.testers.runNixOSTest {
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
              # under programs.dsh. dshBundleCheckHook validates the composed
              # profile at build time.
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
                  bundles = [
                    pkgs.dsh.bundles.web-app
                    pkgs.dsh.bundles.subagent-codex
                    pkgs.dsh.bundles.subagent-claude-code
                  ];
                  agentPreset = "web-subagents";
                  patch = ''
                    # served by programs.dsh.profiles
                    []
                  '';
                };
                agentPresets.web-subagents = {
                  source = "standard";
                  enableTools = [ "tool-subagent-codex" ];
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
              "test -f /var/lib/dsh/cli-home/.agent-presets/web-subagents/agent.cordis.yml; yq -e '[.. | select(type == \"!!map\") | select(.id == \"tool-subagent-codex\" and has(\"disabled\"))] | length == 0' /var/lib/dsh/cli-home/.agent-presets/web-subagents/agent.cordis.yml; yq -e '[.. | select(type == \"!!map\") | select(.id == \"tool-subagent-claude-code\" and .disabled == true)] | length == 1' /var/lib/dsh/cli-home/.agent-presets/web-subagents/agent.cordis.yml"
            )
            machine.succeed(
              "yq -e 'length == 1 and .[0].id == \"agent-presets\" and .[0].config.default == \"web-subagents\"' /var/lib/dsh/cli-home/profiles/nix-web/cordis.patch.yml"
            )
            machine.succeed(
              "yq -e '.dependencies.\"@deepseek-ai/dsh-subagent-codex\" != null and .dependencies.\"@deepseek-ai/dsh-subagent-claude-code\" != null' $(dirname $(dirname $(readlink -f /run/current-system/sw/bin/dsh)))/lib/deepseek-harness/package.json"
            )
            machine.succeed(
              "yq -e '[.. | select(type == \"!!map\") | select(.id == \"tool-subagent-codex\" and .disabled == true)] | length == 1' ${pkgs.dsh.dsh-kernel}/lib/deepseek-harness/config/agent-presets/standard/agent.cordis.yml"
            )
            machine.succeed(
              "yq -e '[.. | select(type == \"!!map\") | select(.id == \"tool-subagent-claude-code\" and .disabled == true)] | length == 1' ${pkgs.dsh.dsh-kernel}/lib/deepseek-harness/config/agent-presets/standard/agent.cordis.yml"
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
            machine.succeed(
              "! systemd-cgls --unit dsh-web.service --no-pager | grep -Eiq 'codex|claude'"
            )
          '';
        };
      };
    };
}
