{ ... }:
{
  flake.homeModules.ai =
    { config, lib, ... }:
    lib.mkIf
      (builtins.elem config.home.username [
        "vir"
        "capcu"
      ])
      {
        home.file.".config/opencode/AGENTS.md".text = ''
          # General Coding Instructions

          Follow the repository's existing conventions and make the smallest correct change.
          Format modified files and run the relevant checks before finishing.

          ## Nix

          - Use `nixfmt` for Nix formatting. If `nix fmt` is available, use that.
          - Prefer declarative Nix expressions and existing module options over imperative scripts.
          - Keep expressions simple; factor out bindings only when they improve clarity or avoid repetition.
          - Pin external inputs through the flake lock file. Do not use impure fetches.
          - Prompt the user to evaluate the affected flake or configuration after changes when practical instead of running the checks.

          ## Python

          - Target the project's configured Python version and dependency tooling.
          - Use the functional paradigm, dataclasses, pure functions, minimize mutable state and shadowing variables, etc. but no unnecessary functions that just pass their parameters to another function.
          - Use as many modern python type hints as possible
          - Keep functions focused and handle expected errors explicitly.
        '';
      };
}
