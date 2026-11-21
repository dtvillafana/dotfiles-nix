"""Overlay Nix-managed settings without removing Agent Deck's own entries."""

import os
import sys
from collections.abc import MutableMapping
from pathlib import Path
from tempfile import NamedTemporaryFile

import tomlkit


def overlay(current: MutableMapping, managed: MutableMapping) -> None:
    for key, value in managed.items():
        existing = current.get(key)
        if isinstance(existing, MutableMapping) and isinstance(value, MutableMapping):
            overlay(existing, value)
        elif key not in current or type(existing) is not type(value) or existing != value:
            current[key] = value


def merge_config(defaults: Path, preferred: Path, legacy: Path) -> None:
    target = preferred
    if not preferred.exists() and not preferred.is_symlink():
        if legacy.exists() or legacy.is_symlink():
            target = legacy
    if target.is_symlink():
        target = target.resolve(strict=True)

    managed_text = defaults.read_bytes()
    managed = tomlkit.parse(managed_text)
    original = target.read_bytes() if target.exists() else None
    if original is None:
        updated = managed_text
    else:
        current = tomlkit.parse(original)
        overlay(current, managed)
        updated = tomlkit.dumps(current).encode()
        if updated == original:
            return

    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        with NamedTemporaryFile(dir=target.parent, delete=False) as file:
            temporary = Path(file.name)
            file.write(updated)
            file.flush()
            os.fsync(file.fileno())
        latest = target.read_bytes() if target.exists() else None
        if latest != original:
            raise RuntimeError(f"{target} changed during activation; retry the merge")
        temporary.replace(target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    merge_config(*(Path(arg) for arg in sys.argv[1:]))
