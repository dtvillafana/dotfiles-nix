# Mouse-follow zoom on Hyprland

After rebuilding and starting a new graphical session:

1. In OBS, add a **Window Capture (PipeWire)** source and select your window.
   Keep it as a direct source in the scene (not inside a group/nested scene).
2. Right-click the source → **Transform → Reset Transform**, then **Fit to Screen**.
   Rotated sources and bounding-box transforms are not supported.
3. Open **Tools → Scripts → +** and load
   `~/.config/obs-studio/scripts/hyprland-zoom.lua`.
4. In the script settings, select that capture source. Zoom defaults to **2×**.
5. Right-click the scene in the Scenes list → **Fullscreen Projector (Scene)**
   and choose your second monitor. A Source Projector does not include this zoom.
6. Focus the **same window you selected in the capture**, then press
   **Super+Shift+Z** to zoom and follow the pointer. Press again to restore.

The shortcut locks onto the active window when enabled. Moving/resizing it is
supported; moving the pointer outside it clamps the projected view to its edges.
The script cannot infer which window you chose in PipeWire's capture picker:
always activate zoom while the captured window is focused. This is for individual
window capture, not monitor capture. Capture the whole window without additional
crop/scale filters for correct pointer mapping. Desktop display scaling is supported.

The original scene-item crop/transform is restored on disable, scene switch, script
unload, or loss of the bridge heartbeat. Avoid editing the source transform while
zoom is active; those edits would be replaced on restore. Disable zoom before
saving/exporting a scene collection or quitting OBS (a crash can leave OBS's saved
transform zoomed; Reset Transform and Fit to Screen recover it).

Troubleshooting:

- Bridge status/logs: `systemctl --user status obs-hyprland-zoom`
  and `journalctl --user -u obs-hyprland-zoom`.
- If applying without a new login, run
  `systemctl --user start obs-hyprland-zoom` after rebuilding.
- OBS script errors: **Tools → Scripts → Script Log**.
- If the shortcut conflicts, change the binding in `modules/hm-features/obs-zoom.nix`.
  It runs `obs-hyprland-zoom --toggle`; no OBS global-hotkey plugin is needed.
- A closed/hidden captured window unzooms; toggle off/on over the intended window
  if its identity changes. The zoom is immediate, with pointer tracking at ~30 Hz.

This is a local custom integration, not an upstream OBS plugin. No network server,
OBS websocket password, X11 access, or extra external source input is needed.
