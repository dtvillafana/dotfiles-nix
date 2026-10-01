# Hyprland desktop (all Linux nodes and users)

`vir`, `capcu`, and `guest` now use Hyprland 0.55.4 from the existing flake
lock, with UWSM, XWayland for legacy applications, PipeWire, the Hyprland
screencast portal, and GTK file-picker portals. This applies wherever those
users exist on rogdesktop, capcuDell, thinkpad, hpenvynix, and cap765, including
bootstrap configurations. Nix-on-Droid stays terminal-only: Android does not
provide a NixOS graphical/login session.

## Replacements

| Previous component | Replacement |
| --- | --- |
| i3 / guest Plasma | Hyprland with the existing Super shortcuts and named workspaces |
| i3status / i3bar | Waybar, including workspace, audio, network, and tray modules |
| x0vncserver | WayVNC with screen capture, keyboard, mouse, and clipboard support |
| xdotool password typing | wtype; keepmenu also uses its wtype backend |
| xdotool mouse mode | ydotool and its system input-simulation service |
| scrot / xclip screenshot and OCR | grim / slurp / Tesseract / wl-clipboard |
| feh wallpaper | swaybg, using `~/pictures/wallpaper.jpg` |
| xss-lock / i3lock | hypridle / hyprlock, including explicit lock and pre-suspend lock |
| autorandr / ARandR | Hyprland hotplug monitor rules / wdisplays |
| X11 display guessing for xdg-open | Current UWSM activation environment for detached shells |

Rofi's pinned version supports Wayland; dunst, NetworkManager's tray applet,
and the installed GUI applications are retained. XWayland remains enabled
because some applications still require X11; it is not an Xorg desktop session.
The old i3, startx, autorandr, and Plasma session definitions are removed.

## Build before switching

Use a path flake URL so newly created files are included without staging your
other changes. First build the configuration **on each matching node**:

```sh
sudo nixos-rebuild build --flake "path:$PWD#capcuDell"
```

Replace `capcuDell` with `rogdesktop`, `thinkpad`, `hpenvynix`, or `cap765`.
Append `Bootstrap` when building without secrets. These builds evaluate the
complete system and Home Manager configurations; the local syntax checks alone
do not prove that every host builds or that its graphics hardware works.

Save your work and switch from a TTY or SSH, not a running desktop terminal:

```sh
sudo nixos-rebuild switch --flake "path:$PWD#capcuDell"
```

The Dell uses a Wayland SDDM greeter and defaults to **Hyprland (UWSM)**.
Other hosts keep their existing TTY login workflow; log out and back in to pick
up ydotool group membership, then run:

```sh
uwsm start hyprland-uwsm.desktop
```

Do not start Hyprland inside an old X11 session. There is no configured i3
fallback now; retain the previous NixOS generation for rollback. Do not roll
out unattended to all nodes before testing one locally.

## VNC

WayVNC starts with each user's graphical session and stops with it. It captures
all outputs, disables client-driven display resizing, and binds only to
`127.0.0.1`. No firewall ports are opened. Ports are:

| Session | Port |
| --- | --- |
| capcu on capcuDell | 5901 |
| capcu on other nodes | 5900 |
| vir | 5902 |
| guest | 5903 |
| Dell SDDM login screen | 5901 |

The Dell greeter runs a minimal Hyprland compositor and its own WayVNC process.
On login, that compositor exits and capcu's WayVNC service takes over the same
port. **The VNC connection will drop; reconnect after login or logout.** This
handoff needs testing on the actual Dell before depending on remote-only access.
Logging into a different user means connecting to that user's port instead.
Other nodes require a running user session; WayVNC does not itself create a
session or provide a login screen. Inactive VT sessions may stop rendering.

Example SSH tunnel for the Dell, then connect your viewer to `localhost:5901`:

```sh
ssh -N -L 5901:127.0.0.1:5901 capcu@capcuDell
```

Like the old configuration, VNC has no separate password: SSH is the remote
authentication/encryption boundary. **Local users can also connect to these
loopback listeners.** Do not change the bind address to a public interface
without configuring VNC authentication and encryption.

## Applications and screen sharing

- Browsers and Electron apps receive `NIXOS_OZONE_WL=1` through UWSM. Legacy
  applications can still run through XWayland; do not globally force all GTK/Qt
  programs to Wayland.
- In OBS, replace Xcomposite sources with **Screen Capture (PipeWire)** and
  select a browser window, not a monitor, for individual-window capture.
  The browser rule enables `render_unfocused` for hidden workspaces. Record a
  short workspace-switching test: applications can still throttle themselves,
  and NVIDIA/portal issues can affect capture. This rule uses extra GPU/power.
- Teams and browser meetings should select screens/windows through the portal.
  Test microphone, camera, audio, and sharing before a meeting.
- Webex is retained, but its native client's Wayland screen-sharing support
  depends on the vendor build. If sharing fails, use a supported browser client;
  XWayland alone cannot capture the complete Wayland desktop.
- Handy starts in the UWSM graphical session. Verify its global hotkey and text
  insertion; compositor-level shortcuts are not identical to X11 global grabs.
- Super+Shift+G opens capcu's keepmenu database when secrets are enabled.
  Test username/password/Tab auto-typing into both native and XWayland apps.
  KeePassXC's own X11 auto-type is not made Wayland-compatible by this change;
  use keepmenu for auto-typing.

## Monitors and hardware

`modules/hm-features/monitors.nix` contains the translated rogdesktop, ThinkPad,
and Dell office positions/modes, including the portrait HDMI monitor. Unknown
outputs remain enabled at their preferred modes instead of being disabled by
an old XRandR profile. Hyprland applies rules again on hotplug.

**Verify connector names with `hyprctl monitors all`.** Dock/MST/DisplayLink
names can differ from X11; the translated Dell `DP-2`/`DP-1-7` assumptions may
need adjustment. Use wdisplays for interactive arrangement, then update the
Nix-generated Lua rules to persist it; reloading the configuration restores
those rules. The ThinkPad's fixed internal-screen position also applies when
undocked.

The Dell retains DisplayLink/evdi and NVIDIA modesetting. Its X11 reverse-PRIME
setup is replaced with NVIDIA render offload; Hyprland manages DRM outputs.
DisplayLink support and multi-GPU output routing are hardware/driver-dependent,
not guaranteed by config validation. Test the dock, unplug/replug, suspend,
and resume locally. `nvidia-offload` remains available for individual apps.

## Shortcuts and diagnostics

Super remains the main modifier. Workspace names, directional focus/movement,
resize/system/bar/workspace/mouse modes, gopass typing, audio, brightness, and
screenshot/OCR shortcuts carry over. Notable differences:

- Super+B/V preselect the next split right/down.
- Super+W/S toggle a tabbed group, not i3's arbitrary container tree or stacks.
- Super+A focuses the previous window; Super+Space cycles windows.
- Super+Shift+C/R reload the configuration, not restart the compositor.
- Super+Ctrl+R (i3 title formatting) has no equivalent and is omitted.
- Super+Shift+T uses a PolicyKit prompt to kill another user's process.
- Super+P/Shift+P disable/enable devices whose names contain `touchpad`.

All three desktop users can access ydotool's input-simulation socket. This
allows input injection, not access to raw physical input events. Gopass secrets
are passed to wtype through stdin, not process arguments. There are no idle
screen-off timers, preserving the previous rogdesktop behavior.

After logging in, check:

```sh
hyprctl configerrors
hyprctl monitors all
hyprctl clients
systemctl --user status wayvnc hyprpolkitagent handy
systemctl --user status xdg-desktop-portal xdg-desktop-portal-hyprland
journalctl --user -b -u wayvnc
```

On guest, omit `handy` because that service is not installed. On the Dell,
also inspect `journalctl -b -u display-manager` if the greeter or its VNC server
fails. Verify lock/unlock, suspend/resume, screenshots/OCR, password typing,
clipboard exchange, and VNC keyboard/mouse before migrating the remaining nodes.
