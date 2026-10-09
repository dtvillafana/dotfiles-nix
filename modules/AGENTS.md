# Module architecture

- Follow the dendritic structure: each feature file is a flake-parts module exporting named `flake.nixosModules` or `flake.homeModules` definitions.
- `import-tree` discovers feature definitions; discovery must not enable features globally. Hosts and user profiles select features through explicit imports.
- Keep a feature's packages, services, timers, scripts, and feature-specific secrets together. Import prerequisite modules from the feature when needed.
- Do not add a catch-all `common` module or put optional features into `baseSystem`. The latter is for baseline OS identity, locale, access, and command-line tools.
- Select host-specific features in `modules/hosts/<host>/default.nix`, not by hostname conditionals in shared modules.
- Preserve normal and bootstrap configurations when changing host composition; `secretsEnabled` guards are intentional.
