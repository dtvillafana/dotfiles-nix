{
  python3,
  protonmail-bridge,
  coreutils,
  writeShellApplication,
}:
let
  python = python3.withPackages (ps: [ ps.mcp ]);
in
writeShellApplication {
  name = "protonmail-bridge-mcp";
  runtimeInputs = [
    python
    protonmail-bridge
    coreutils
  ];
  text = ''
    bridge_ready() {
      python3 -c 'import socket; s=socket.create_connection(("127.0.0.1", 1143), 1); s.close()' 2>/dev/null
    }
    if ! bridge_ready; then
      echo "Starting protonmail-bridge on 127.0.0.1:1143..." >&2
      nohup protonmail-bridge --noninteractive >/dev/null 2>&1 &
      disown || true
      for ((i = 0; i < 40; i++)); do
        if bridge_ready; then
          break
        fi
        sleep 0.5
      done
      if ! bridge_ready; then
        echo "Proton Mail Bridge did not start. Run protonmail-bridge --cli to sign in." >&2
        exit 1
      fi
    fi
    exec python3 ${./mcp_email.py} "$@"
  '';
}
