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
`thinkpadBootstrap`, `hpenvynixBootstrap`, `cap765Bootstrap`, and `hp-xeonBootstrap`.

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

## Proton Mail MCP (vir)

The `protonMail` Home Manager feature installs `protonmail-bridge-mcp` and registers
`protonmail_bridge` plus the Proton Mail skill globally in OpenCode. It uses the
vendored server from NDRL-notes; that checkout is not needed at runtime.

After switching, sign in with `protonmail-bridge --cli` if needed, then run
`protonmail-bridge-mcp --configure` with the Bridge-generated IMAP password.
Existing credentials in `$XDG_CONFIG_HOME/ndrl-board/bridge.env` (normally
`~/.config/ndrl-board/bridge.env`) are reused, never copied into the Nix store.
The server starts Bridge when its local IMAP port is unavailable.

Use `/mcps` to verify the connection. Attachments are confined to the active
project, or `NDRL_BOARD_ROOT` when explicitly set. Sending still requires approval
of the exact recipients, subject, and body. A project-local server with the same
name overrides the global entry; remove that entry to use the packaged version.

## Buddy GitHub watcher

`rogdesktop` runs the Buddy watcher for `vir` via Home Manager. The feature
registers or updates the loopback watcher, merges its GitHub sender routes,
and starts a headless Agent Deck engine and a Cloudflare Quick Tunnel.
SOPS installs the webhook signing secret and repo-scoped worker PAT at
runtime; neither plaintext value is part of a Nix build.

The machine still needs the `master` conductor configured and running,
`opencode2` authenticated, a checkout at `~/git-repos/i-got-a-buddy-web`, and
`gh` authenticated as a repo administrator to update and inspect deliveries
for existing hook `715126227`. Those logins, the hook itself, and the GitHub
label are not created by activation. Agent Deck's database, worktrees and
per-issue dispatch claims are writable state; back them up if migrating.
The tunnel is temporary and updates only that hook's URL and signing
configuration when it reconnects. Headscale is unchanged.

On the first switch from the manual setup, run
`systemctl --user disable --now github-watcher-tunnel agent-deck-watcher-engine`
as `vir` just before rebuilding. Home Manager backs up the two unmanaged
unit files, the dispatcher and the conductor policy to `.hm-bak` files;
check for existing backups with those names before switching. After the
switch, check both units and run
`~/.local/libexec/agent-deck/buddy-issues.py --dry-run`.
Nix's Git flake only sees tracked files: add the new module, helpers and
encrypted secrets to Git before rebuilding, or explicitly use `path:.#rogdesktop`.

If GitHub invalidates the worker token or you rotate the webhook secret,
update `secrets/buddy-watcher.json` through SOPS and rebuild. Restart
`agent-deck-watcher-engine` and then `github-watcher-tunnel` if needed.

## Headscale

Normal NixOS hosts connect to `https://ts.dvilla.me` automatically (the connection is
shared by all users), except `capcuDell`, where Tailscale is disabled because the
office firewall blocks Headscale. The tunnel UDP port is open, exit-node client
routing is enabled, and failed enrollment/settings attempts retry automatically.
`secrets/secrets.json` must contain a valid, reusable `headscale_preauth_key`, and
each host must have a user SSH key that can decrypt that file. When adding a new
recipient to `.sops.yaml`, run `sops updatekeys secrets/secrets.json` to update the
encrypted file too. Bootstrap configurations do not connect automatically.

After switching, check `tailscale status` and
`systemctl status tailscaled-autoconnect`. `hpenvynix` still needs its user public
key enrolled as a SOPS recipient before automatic enrollment can work with its own key.
On Nix-on-Droid, use the native Android Tailscale app with `https://ts.dvilla.me`
as its alternate coordination server; the NixOS systemd service does not apply there.

`headscale-toggle` switches between mesh-only mode and using
`nixos-headscale-linode` as the exit node with Headscale-managed DNS.
Mesh-only mode uses the normal default route and DNS, except that hostnames and
`git.dvilla.me` still resolve through Headscale and connect over the tailnet.
Tailnet devices remain accessible in both modes. The command requires sudo access
and brings Tailscale up if it is disconnected, explicitly using `https://ts.dvilla.me`.
After a reboot or configuration switch, it defaults to mesh-only mode.
Check `tailscaled-autoconnect.service` if Headscale is not connected.
The toggle reads the configured exit-node preference, not peer reachability.
It waits for `tailscale set` and `tailscale up` to finish; if this takes many seconds, check
`journalctl -u tailscaled` for daemon/control-server errors. A configuration
switch can reapply the mesh-only defaults through `tailscaled-set.service`.

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

### SSH access between NixOS hosts

`secrets/ssh-public-keys.nix` lists the users' generated SSH public keys by host and
username. Every NixOS host (including bootstrap configurations) authorizes all listed
keys for its existing `vir` and `capcu` accounts; root and guest are unchanged.
SSH clients offer `~/.ssh/id_ed25519` as well as the existing SOPS-managed key.
Private keys stay on their originating machines.

To enroll another key, copy that user's `~/.ssh/id_ed25519.pub` into the registry
and rebuild every destination host. The registry currently includes `vir` and `capcu`
on `rogdesktop`, `capcu` on `capcuDell`, and `vir` on `hp-xeon` and `thinkpad`.
The keys for `capcu` on `thinkpad`, `vir` and `capcu` on `hpenvynix`, and `capcu`
on `cap765` still need to be added.
Do not overwrite existing private keys: they may also be needed to decrypt SOPS secrets.

`~/.config/sops/age/keys.txt` may be populated from gopass for interactive SOPS use. NixOS secret
activation uses `/home/USERNAME/.ssh/id_ed25519`.

```bash
gopass clone vps:~/git-repos/pass
# If gpg needs to be restarted after switching:
gpgconf --kill gpg-agent
gpg-agent --daemon
```

The `capcu` profile treats encrypted gopass entries as binary in Git diffs.
On activation it removes gopass's default decrypt-on-diff hook from the
existing root store, so Git history and diffs don't open pinentry. Use
`gopass show <entry>` or `gopass history --password <entry>` to intentionally
decrypt current or historical values.

To inspect a plaintext diff without restoring the hook, run this in a
foreground shell where it is safe to display both versions of the secret:

```bash
gopass git -- --no-pager -c 'diff.gpg.textconv=gpg --no-tty --decrypt' \
  diff HEAD^ HEAD -- path/to/entry.gpg
```

# First time setup notes

1. First-time setup may require setting the profile user's password from the root account with `passwd`.
2. You may have to connect to predefined SSH hosts to add them to `known_hosts`.

## Attach to remote Agent Deck sessions

Run Agent Deck on the machine where you copy the screenshot, not inside an SSH
shell. Register the SSH host once, then attach to the existing session:

```sh
agent-deck remote add work capcu@capcuDell
agent-deck remote attach work <session-title-or-id>
```

Home Manager merges its settings into a writable Agent Deck config on each
activation. Nix wins for keys it defines; other keys, including remotes added
with `remote add`, are preserved. Agent Deck's saved sessions are not touched.
If `remote add` reports a read-only Nix store path, apply the updated Home
Manager configuration on the client first.
If SSH cannot find the remote binary on its default `PATH`, pass
`--agent-deck-path /etc/profiles/per-user/capcu/bin/agent-deck` to `remote add`.

The current Agent Deck build doesn't forward clipboard images to OpenCode 2.
To attach an image, copy it to the server with `scp`, then paste its absolute
server path by itself into OpenCode.
