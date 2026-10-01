# nixos-configs

These are David's nixos configs

# Fresh installation

Use the bootstrap variant of the matching host configuration for the first switch. It contains the
normal system and home configuration, but omits SOPS secrets and features that require them.

```bash
sudo nixos-rebuild switch \
  --flake "github:dtvillafana/dotfiles-nix#nodenameBootstrap" \
  --extra-experimental-features "nix-command flakes"
```

Available bootstrap configurations are `rogdesktopBootstrap`, `capcuDellBootstrap`,
`thinkpadBootstrap`, `hpenvynixBootstrap`, and `cap765Bootstrap`.

Set the profile user's password if needed, then install the existing recipient SSH private key at
`/home/USERNAME/.ssh/id_ed25519`. The key must be owned by that user and have mode `0600`. A newly
generated key cannot decrypt the existing secrets until the secrets are re-encrypted for it.

Switch to the normal configuration after the required keys are installed:

```bash
sudo nixos-rebuild switch --flake "github:dtvillafana/dotfiles-nix#nodename"
```

For a local checkout, use `path:/home/vir/git-repos/dotfiles-nix` instead of the GitHub flake URL.

# Additional setup

## Hyprland desktop

All Linux desktop users (`vir`, `capcu`, and `guest`) use Hyprland with UWSM.
See [the migration guide](modules/hm-features/hyprland/README.md) for building
each node, the Wayland replacements, VNC ports, and required hardware tests.
Nix-on-Droid remains terminal-only.

## Blender MCP (vir)

The configuration installs MCP for Blender and its matching add-on, and registers
the `blender` MCP server in OpenCode. The server connects to `localhost:9876`;
telemetry is disabled. No `uvx` or upstream setup script is needed.

After switching the configuration:

1. Open Blender, go to **Edit → Preferences → Add-ons**, search for **MCP for Blender**,
   and enable it. Save Preferences if automatic saving is disabled.
2. In the 3D viewport, press **N** and open the **MCP for Blender** tab. If the server
   is not already running, click **Start MCP Server**.
3. Restart OpenCode and use `/mcps` to check the `blender` connection. Ask OpenCode
   to inspect the current Blender scene as an end-to-end check.

Keep the add-on bound to localhost: its socket can execute Python inside Blender
and has no authentication. Save your scene before asking an agent to modify it.
This setup targets stock Blender; only one Blender instance should listen on port
9876 at a time. Enable optional asset integrations and their credentials in Blender
only when needed.

## Headscale

Normal NixOS hosts connect to `https://ts.dvilla.me` automatically (the connection is
shared by all users). Replace the encrypted `headscale_preauth_key` placeholder in
`secrets/secrets.json` with a valid, reusable Headscale preauth key using
`sops secrets/secrets.json` before switching configurations. Bootstrap configurations
do not connect automatically.

`headscale-toggle` switches the exit node and DNS, but keeps the host connected to
Headscale in both states. On uses `nixos-headscale-linode` as the exit node and
Headscale-managed DNS. Off uses the normal default route and DNS, except that
`git.dvilla.me` still resolves through Headscale and connects over the tailnet.
The toggle requires sudo access. After a reboot or configuration switch, it defaults
to off. Check `tailscaled-autoconnect.service` if Headscale is not connected.
The toggle reads the configured exit-node preference, not peer reachability.
It waits for `tailscale set` to finish; if this takes many seconds, check
`journalctl -u tailscaled` for daemon/control-server errors. A configuration
switch can reapply the off defaults through `tailscaled-set.service`.

## Nix-on-Droid

Install [Nix-on-Droid](https://github.com/nix-community/nix-on-droid) on an aarch64 Android
device, then switch to the flake configuration:

```bash
nix-on-droid switch --flake "github:dtvillafana/dotfiles-nix#default"
```

The `default` output is under `nixOnDroidConfigurations`; use
`path:/path/to/dotfiles-nix#default` for a local checkout. It includes the shared Git and tmux Home
Manager modules.

## Secrets

`~/.config/sops/age/keys.txt` may be populated from gopass for interactive SOPS use. NixOS secret
activation uses `/home/USERNAME/.ssh/id_ed25519`.

```bash
gopass clone vps:~/git-repos/pass
# If gpg needs to be restarted after switching:
gpgconf --kill gpg-agent
gpg-agent --daemon
```

# First time setup notes

1. First-time setup may require setting the profile user's password from the root account with `passwd`.
2. You may have to connect to predefined SSH hosts to add them to `known_hosts`.
