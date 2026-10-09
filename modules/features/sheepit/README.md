# Idle SheepIt workers

Selected explicitly by rogdesktop and hp-xeon. Bootstrap configurations omit the
services. Both hosts use the official pinned legacy client 7.26132 (no updater),
because GTX 1070/1060 GPUs are Pascal and the X5690 also lacks AVX. GPU detection
was tested successfully on both hosts using the packaged client (`OPTIX_0`).
Actual frame compatibility and legacy work availability still need an account test.

## Activate

Evaluate the changed normal and bootstrap configurations before rebuilding:

```sh
nix eval .#nixosConfigurations.rogdesktop.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.rogdesktopBootstrap.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.hp-xeon.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.hp-xeonBootstrap.config.system.build.toplevel.drvPath
```

Both hosts automatically use `secrets/sheepit.yaml`, encrypted for primary,
vir-rog, and hp-xeon. The committed secret starts empty, so rendering stays
blocked until you provision it. Edit locally (do not paste the key into chat):

```sh
sops secrets/sheepit.yaml
```

Replace the empty value with these Java properties, using a render key rather
than your account password:

```yaml
sheepit-config: |
  login=YOUR_USERNAME
  password=YOUR_RENDER_KEY
```

Save and exit so SOPS re-encrypts the file, then rebuild each host using your
usual deployment process. No manual per-host credentials file is needed.
The feature owns the root-only SOPS secret declaration. systemd loads a private
runtime credential; the key never appears in argv or the Nix store. Key changes
restart the idle controller, which stops the worker and starts a fresh idle
interval rather than bypassing the idle policy. Bootstrap configurations do not
require or decrypt this secret.

## Policy

- Wait 15 minutes with no keyboard/mouse/gamepad activity. Covers multiple local
  users, TTYs, and logged-out seats without compositor-specific idle hints.
- A small **root** controller reads input event types only and discards their
  contents. It never grabs devices, stores keystrokes, or gives renderers input access.
- No input devices or a device inventory change resets/inhibits idle eligibility.
- Remote login sessions and other NVIDIA compute processes inhibit rendering.
  This is conservative: an idle SSH login or loaded Ollama model can block work.
- Not every non-compute GPU workload is detected (e.g. unattended games).
  Disable manually for those or add a workload-specific exclusion later.
- Reserve 10 GiB free disk; cache is dedicated to SheepIt and client-managed.
- Returning activity stops the whole worker cgroup (up to a few seconds plus query
  latency), losing unfinished-frame credit. It does not just pause new jobs.
- Suspend/resume restarts the idle interval. Low CPU/I/O weight and per-host RAM
  limits are not GPU priority or GPU power limits.
- Renderers run as the dedicated sheepit user. The FHS wrapper is a compatibility
  environment, **not** a security sandbox. Do not store personal files in its home.

## Control and verification

```sh
# Disable until you remove this marker:
sudo touch /var/lib/sheepit/disabled
sudo systemctl stop sheepit.service
# Re-enable:
sudo rm /var/lib/sheepit/disabled
# Observe:
journalctl -u sheepit-idle -u sheepit -f
```

Close SSH connections, wait 15 minutes, verify a completed frame and account
points, then return and check the GPU is released. Repeat with another compute
workload and suspend/resume. Compare points/hour, heat, and electricity before
deciding whether both machines are worth running. Old-compatible job supply is
not guaranteed.

Policy unit tests: `python3 modules/features/sheepit/test_idle.py`.
