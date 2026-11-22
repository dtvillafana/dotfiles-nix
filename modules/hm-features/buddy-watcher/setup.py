"""Reconcile the Buddy watcher on service startup without replacing other routes."""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def agent_deck(*args: str, env: dict[str, str] | None = None) -> str:
    return subprocess.run(
        ["agent-deck", "-p", "default", "watcher", *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        env=env,
    ).stdout


def write_private(path: Path, content: str) -> None:
    if path.exists() and path.stat().st_mode & 0o777 == 0o600 and path.read_text() == content:
        return
    with tempfile.NamedTemporaryFile(
        mode="w", dir=path.parent, delete=False, encoding="utf-8"
    ) as temporary:
        name = Path(temporary.name)
        try:
            temporary.write(content)
            temporary.flush()
            name.replace(path)
        finally:
            name.unlink(missing_ok=True)


def reconcile(directory: Path, watcher: str, port: str, secret_path: Path) -> None:
    secret = secret_path.read_text().strip()
    if not secret:
        raise ValueError("missing GitHub webhook signing secret")
    rows = json.loads(agent_deck("list", "--json")) or []
    row = next((row for row in rows if row["name"] == watcher), None)
    if row is None:
        agent_deck(
            "create", "github", "--name", watcher, "--port", port,
            "--secret-file", str(secret_path),
            env={key: value for key, value in os.environ.items() if key != "GITHUB_WEBHOOK_SECRET"},
        )
    elif row["type"] != "github":
        raise ValueError(f"{watcher} already exists with a different adapter")
    status = json.loads(agent_deck("status", watcher, "--json"))
    actual_dir = Path(status["config_path"])
    if actual_dir != directory / watcher:
        raise ValueError(f"unexpected watcher path: {actual_dir}")
    write_private(
        actual_dir / "watcher.toml",
        f'[source]\nbind = "127.0.0.1"\nport = "{port}"\nsecret = {json.dumps(secret)}\n',
    )
    routes_file = directory / "clients.json"
    routes = json.loads(routes_file.read_text()) if routes_file.exists() else {}
    route = {"conductor": "master", "group": "conductor", "name": "i-got-a-buddy-web GitHub"}
    routes.update({"*@github.com": route, "*@users.noreply.github.com": route})
    write_private(routes_file, json.dumps(routes, indent=2) + "\n")
    if status["status"] != "running":
        agent_deck("start", watcher)


if __name__ == "__main__":
    directory, watcher, port, secret = sys.argv[1:]
    reconcile(Path(directory), watcher, port, Path(secret))
