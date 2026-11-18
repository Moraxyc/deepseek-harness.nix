{ lib, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      smoke = lib.getExe pkgs.dsh.dsh-profile-smoke;
      # Behaves as the profile named in `--profile NAME` asks.
      fakeDsh = pkgs.writeShellScript "fake-dsh" ''
        profile=$2
        case "$profile" in
          ok) echo booted ;;
          dropped) echo 'dsh: skipping profile bundle "x": incompatible' >&2 ;;
          inactive) echo 'dsh: warning: 1 entry did not activate' >&2 ;;
          failing) exit 3 ;;
          transport) echo 'dsh: TRANSPORT: connection refused' >&2; exit 1 ;;
          interactive) sleep 30 ;;
          acp)
            read -r _
            echo '{"jsonrpc":"2.0","id":1,"result":{}}'
            sleep 30
            ;;
          web)
            ${lib.getExe pkgs.python3Minimal} -c '
        import http.server, socketserver
        with socketserver.TCPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler) as s:
            print(f"dsh web: http://127.0.0.1:{s.server_address[1]}/", flush=True)
            s.serve_forever()
        '
            ;;
          silent-web) sleep 30 ;;
        esac
      '';
    in
    {
      checks.dsh-profile-smoke =
        pkgs.runCommand "dsh-profile-smoke" { __darwinAllowLocalNetworking = true; }
          ''
            pass() { ${smoke} --log "$TMPDIR/log" --timeout 5 "$@" || { echo "expected success: $*"; exit 1; }; }
            fails() { if ${smoke} --log "$TMPDIR/log" --timeout 5 "$@"; then echo "expected failure: $*"; exit 1; fi; }

            pass ${fakeDsh} ok plain
            fails ${fakeDsh} dropped plain
            pass --allow-skip x ${fakeDsh} dropped plain
            fails ${fakeDsh} inactive plain
            fails ${fakeDsh} failing plain
            fails ${fakeDsh} transport plain
            pass --until-provider ${fakeDsh} transport plain
            fails ${fakeDsh} interactive plain
            pass ${fakeDsh} interactive tty
            fails ${fakeDsh} failing tty
            pass ${fakeDsh} acp acp
            fails ${fakeDsh} interactive acp
            pass ${fakeDsh} web web
            fails ${fakeDsh} silent-web web
            touch "$out"
          '';
    };
}
