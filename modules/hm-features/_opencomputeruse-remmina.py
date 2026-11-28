"""Expose only Remmina's session and input tools over MCP stdio."""

import json
import hmac
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PAGE = Path(__file__).with_name("_opencomputeruse-remmina.html")

TOOLS = {
    "start_session",
    "end_session",
    "list_sessions",
    "list_windows",
    "screenshot",
    "get_ui_tree",
    "click",
    "move_mouse",
    "drag",
    "scroll",
    "type_text",
    "press_key",
    "set_value",
    "element_action",
    "wait",
}
METHODS = {"initialize", "ping", "tools/list", "tools/call"}
EMPTY_LISTS = {
    "resources/list": "resources",
    "resources/templates/list": "resourceTemplates",
    "prompts/list": "prompts",
}


def send(stream, message):
    print(json.dumps(message), file=stream, flush=True)


def relay(server, request, launch_remmina):
    reply = {"jsonrpc": "2.0", "id": request["id"]}
    method = request.get("method")
    params = request.get("params", {})

    if isinstance(method, str) and method in EMPTY_LISTS:
        return {**reply, "result": {EMPTY_LISTS[method]: []}}
    if not isinstance(method, str) or method not in METHODS:
        return {**reply, "error": {"code": -32601, "message": "Method not supported"}}
    if not isinstance(params, dict):
        return {**reply, "error": {"code": -32602, "message": "Invalid params"}}

    if method == "tools/call":
        name = params.get("name")
        arguments = params.get("arguments", {})
        if not isinstance(name, str) or name not in TOOLS:
            return {**reply, "error": {"code": -32602, "message": "Tool not allowed"}}
        if name == "start_session":
            if arguments != {}:
                return {
                    **reply,
                    "error": {"code": -32602, "message": "Remmina takes no launch options"},
                }
            arguments = {"app": launch_remmina, "display": "wayland"}
        params = {"name": name, "arguments": arguments}

    send(server.stdin, {**reply, "method": method, "params": params})
    for line in server.stdout:
        response = json.loads(line)
        if "id" in response:
            break
    else:
        raise RuntimeError("OpenComputerUse exited without replying")

    if "result" in response:
        result = response["result"]
        if method == "initialize":
            result["capabilities"] = {"tools": {}}
            result["instructions"] = (
                "This server drives only Remmina, on its own private display. "
                "Call start_session without launch arguments, then use the session ID. "
                "The user can run remmina-agent-view to see and control the same session. "
                "For login, ask the user to sign in there, pause all tool actions and "
                "screenshots, and wait for their confirmation before continuing."
            )
        elif method == "tools/list":
            result["tools"] = [tool for tool in result["tools"] if tool["name"] in TOOLS]
            for tool in result["tools"]:
                if tool["name"] == "start_session":
                    tool["description"] = "Launch Remmina on a private display."
                    tool["inputSchema"] = {
                        "type": "object",
                        "properties": {},
                        "additionalProperties": False,
                    }
    return response


def main():
    if sys.argv[1] == "--open-view":
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
        endpoints = sorted(
            runtime.glob("ocu-remmina-*/view.json"),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
        if not endpoints:
            sys.exit("No Remmina MCP server is running. Connect it in OpenCode first.")
        for endpoint in endpoints:
            data = json.loads(endpoint.read_text())
            try:
                os.kill(data["pid"], 0)
            except ProcessLookupError:
                continue
            subprocess.run(
                [sys.argv[2], f"http://127.0.0.1:{data['port']}/#{data['token']}"],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            return
        sys.exit("No live Remmina MCP server found.")

    executable, launch_remmina, path, xkb_config = sys.argv[1:]
    with tempfile.TemporaryDirectory(prefix="ocu-", dir="/tmp") as directory:
        with subprocess.Popen(
            [executable, "mcp"],
            cwd=directory,
            env={
                "PATH": path,
                "HOME": directory,
                "TMPDIR": directory,
                "XDG_CONFIG_HOME": directory,
                "XDG_RUNTIME_DIR": directory,
                "XKB_CONFIG_ROOT": xkb_config,
                "OCU_MOBILE": "0",
            },
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            encoding="utf-8",
        ) as server:
            lock = threading.Lock()
            token = secrets.token_urlsafe(32)

            class View(BaseHTTPRequestHandler):
                def log_message(self, *_args):
                    # Never log tokens, keystrokes, or credentials.
                    pass

                def respond(self, status, body, content_type):
                    self.send_response(status)
                    self.send_header("Content-Type", content_type)
                    self.send_header("Cache-Control", "no-store")
                    self.send_header("X-Content-Type-Options", "nosniff")
                    self.send_header("Referrer-Policy", "no-referrer")
                    self.send_header("Content-Security-Policy",
                                     "default-src 'none'; script-src 'unsafe-inline'; "
                                     "style-src 'unsafe-inline'; connect-src 'self'; "
                                     "img-src blob:; frame-ancestors 'none'; base-uri 'none'")
                    self.end_headers()
                    self.wfile.write(body)

                def do_GET(self):
                    if self.path == "/":
                        self.respond(200, PAGE.read_bytes(), "text/html; charset=utf-8")
                    else:
                        self.respond(404, b"", "text/plain")

                def do_POST(self):
                    # No cookies or CORS: cross-origin pages cannot authenticate.
                    auth = self.headers.get("Authorization", "")
                    if not hmac.compare_digest(auth, f"Bearer {token}"):
                        self.respond(401, b"", "text/plain")
                        return
                    origin = self.headers.get("Origin")
                    if origin and origin != f"http://127.0.0.1:{self.server.server_port}":
                        self.respond(403, b"", "text/plain")
                        return
                    try:
                        length = int(self.headers.get("Content-Length", "0"))
                        if self.path != "/call" or not 0 < length <= 65536:
                            raise ValueError("Invalid request")
                        params = json.loads(self.rfile.read(length))
                        if not isinstance(params, dict) or params.get("name") not in (
                            TOOLS - {"start_session", "end_session"}
                        ):
                            raise ValueError("Tool not allowed")
                        with lock:
                            response = relay(server, {
                                "jsonrpc": "2.0", "id": "live-view",
                                "method": "tools/call", "params": params,
                            }, launch_remmina)
                        self.respond(200, json.dumps(response).encode(), "application/json")
                    except (ValueError, TypeError):
                        self.respond(400, b"", "text/plain")

            http = ThreadingHTTPServer(("127.0.0.1", 0), View)
            http.daemon_threads = True
            runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
            with tempfile.TemporaryDirectory(prefix="ocu-remmina-", dir=runtime) as view_dir:
                endpoint = Path(view_dir) / "view.json"
                endpoint.touch(mode=0o600)
                endpoint.write_text(json.dumps({
                    "pid": os.getpid(), "port": http.server_port, "token": token,
                }))
                thread = threading.Thread(target=http.serve_forever, daemon=True)
                thread.start()
                try:
                    serve_requests(server, launch_remmina, lock)
                finally:
                    http.shutdown()
                    http.server_close()
                    server.stdin.close()


def serve_requests(server, launch_remmina, lock):
    for line in sys.stdin:
        try:
            request = json.loads(line)
        except ValueError:
            send(
                sys.stdout,
                {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "Invalid JSON"},
                },
            )
            continue
        # Handle one request at a time; notifications need no reply.
        if isinstance(request, dict) and "id" in request:
            with lock:
                send(sys.stdout, relay(server, request, launch_remmina))


if __name__ == "__main__":
    main()
