# General Coding Instructions

Follow the repository's existing conventions and make the smallest correct change.
Format modified files and run the relevant checks before finishing.

## Nix

- Use `nix fmt` for Nix formatting. If `nix fmt` is unavailable use `nixfmt`.
- Prefer declarative Nix expressions and existing module options over imperative scripts.
- Keep expressions simple; factor out bindings only when they improve clarity or avoid repetition.
- Pin external inputs through the flake lock file. Do not use impure fetches.
- Prompt the user to evaluate the affected flake or configuration after changes when practical instead of running the checks.
- If something you're trying needs multiple dependencies, first try to get them all in a nix shell environment, and if this is not a one-off, or this requires NixOS configuration changes, recommend to the user to update their NixOS configuration to support what you are trying to do, then attempt a different method.

## Python

- Target the project's configured Python version and dependency tooling.
- Use the functional paradigm, dataclasses, pure functions, minimize mutable state and shadowing variables, etc. but no unnecessary functions that just pass their parameters to another function.
- Use as many modern python type hints as possible
- Keep functions focused and handle expected errors explicitly.

## Commands

- when you try a command and the program is not available, then try again using `nix shell` to get the desired program before trying something else.
