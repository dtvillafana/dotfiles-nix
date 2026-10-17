# Repository architecture: dendritic Nix

Strictly follow the dendritic pattern for all new or modified Nix configuration. Do not introduce a competing architecture or broaden existing exceptions without explicit user approval. See `modules/AGENTS.md` for module-specific composition rules.

## Required guidance

- Use flake-parts as the top-level module system. Each automatically discovered Nix file under `modules/` must be a top-level flake-parts module, not a standalone NixOS or Home Manager module.
- Organize by feature: one feature may contribute to NixOS, Home Manager, packages, and other outputs from the same top-level module. Keep its related configuration and resources together rather than scattering them by configuration layer.
- Store lower-level modules as named option values, using this repository's `flake.nixosModules` and `flake.homeModules` conventions. Compose them through module imports; do not replace this with ad hoc attribute-set merging or manual function application.
- Keep `flake.nix` focused on inputs and top-level assembly. Let `import-tree` discover feature definitions; select lower-level features explicitly in hosts and user profiles. Discovering a definition must not activate an optional feature globally.
- Importing a selected lower-level feature should enable it. Do not add redundant custom `enable` switches merely to undo unconditional imports; existing upstream NixOS/Home Manager `enable` options remain appropriate inside features.
- Share cross-file values through top-level options and lexical closures where practical. Do not add `specialArgs`/`extraSpecialArgs` plumbing just to transport values already available at the top level. Preserve existing argument wiring unless a requested change requires refactoring it.
- Declare typed top-level options when genuinely needed to model shared data or deferred modules. Reuse meaningful composition names rather than creating a new module name for every implementation detail.
- Keep package expressions in `packages/` and explicitly imported implementation helpers excluded from automatic discovery (for example, `_settings.nix` or an underscore-prefixed directory). These are deliberate exceptions, not a precedent for new parallel module trees.
- When a lower-level module can be imported through multiple dependency paths, ensure stable identity so Nix deduplicates it. Follow existing explicit `key` conventions where needed; do not hide duplicate imports with `mkForce` or `mkDefault`.

## Documentation

The guidance above summarizes these upstream references, adapted to this repository's conventions (consulted 2026-10-16):

- [The Dendritic Pattern](https://github.com/mightyiam/dendritic#readme): top-level feature modules, lower-level module values and merging, automatic importing, and anti-patterns including argument pass-through, module-name proliferation, and redundant enable options.
- [import-tree](https://github.com/vic/import-tree#readme): recursive module discovery; paths containing `/_` are excluded by default.
- [Nix module system](https://nix.dev/tutorials/module-system/): imports, option declarations, merging, and evaluation semantics underlying the pattern.

Before finishing configuration changes, check that discovery stays separate from activation, dependencies remain feature-owned, and host/user composition stays explicit. Format changed Nix files with `nix fmt` and ask the user to evaluate affected configurations when practical.
