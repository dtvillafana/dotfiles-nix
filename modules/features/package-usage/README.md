# Nix package usage on capcuDell

After rebuilding, `nix-package-usage.service` starts collecting automatically.
Check its status with `systemctl status nix-package-usage`.

```sh
sudo nix-package-usage report             # configured packages with bin entries but no observations
sudo nix-package-usage report --all       # include observed packages and their last-seen date
sudo nix-package-usage report --binaries  # unseen executable paths in current package outputs
sudo nix-package-usage report --executed  # all observed Nix store executable paths and counts
```

The collector uses Linux fanotify to observe execution opens on the filesystem
backing `/nix/store`, including short-lived commands and system and user
services. It also snapshots running Nix executables on startup. The root-only
SQLite database in `/var/lib/nix-package-usage/` stores executable paths,
counts, and timestamps—not command arguments, window titles, or service logs.

The report groups observations by the evaluated NixOS and Home Manager package
lists. It remembers previously configured store paths by scope and package
name across upgrades. Package names are derivation names, which may differ from
their nixpkgs attribute names. `--binaries` shows resolved paths for executable
entries under current package outputs' `bin` directories.

Wait for about a month of normal use before reviewing candidates. Execution
opens are not exact successful launch counts: they can include interpreter or
loader opens, and the kernel can coalesce events. Programs outside the Nix
store, shell built-ins, scripts passed as interpreter arguments, and libraries
loaded without execution are not tracked. Services with no entry in the
package lists can still appear in `--executed`, but not as pruning candidates.
A service starting is not evidence that anybody uses it. Do not remove a
package solely because it was not observed.
