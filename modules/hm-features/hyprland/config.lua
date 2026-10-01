-- Hyprland 0.55+ uses Lua. Keep i3's Super shortcuts and named workspaces.
require("monitors")
require("user")

hl.env("NIXOS_OZONE_WL", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = { layout = "dwindle", gaps_in = 0, gaps_out = 0, border_size = 2 },
    decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = false },
    input = { kb_layout = "us", kb_options = "ctrl:swapcaps", follow_mouse = 1 },
    cursor = { no_warps = true },
    dwindle = { preserve_split = true },
    binds = { workspace_back_and_forth = true },
    misc = { disable_hyprland_logo = true, force_default_wallpaper = -1 },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hypridle")
    hl.exec_cmd('test ! -f "$HOME/pictures/wallpaper.jpg" || swaybg -i "$HOME/pictures/wallpaper.jpg" -m fill')
end)

local workspaces = {
    { name = "terminals", class = "(org\\.wezfurlong\\.wezterm|wezterm|ghostty|com\\.mitchellh\\.ghostty)" },
    { name = "web", class = "(qutebrowser|[Bb]rave-browser|[Cc]hromium(-browser)?|firefox|org\\.mozilla\\.firefox)" },
    {
        name = "documents",
        class = "(org\\.pwmt\\.zathura|[Zz]athura|libreoffice.*|kolourpaint|[Ss]office|ONLYOFFICE|DesktopEditors)",
    },
    { name = "media", class = "(vlc|org\\.videolan\\.VLC)" },
    {
        name = "comms",
        class = "([Ss]ignal|org\\.signal\\.Signal|TelegramDesktop|org\\.telegram\\.desktop|Microsoft Teams - Preview|teams-for-linux)",
    },
    { name = "VMs", class = "(\\.virt-manager-wrapped|virt-manager|steam)" },
    { name = "DB", class = "(sqlitebrowser|DB Browser for SQLite)" },
    { name = "SSH", class = "org\\.remmina\\.Remmina" },
    { name = "misc", class = "(pavucontrol|org\\.pulseaudio\\.pavucontrol|wdisplays)" },
    { name = "Background Processes" },
}

for i, workspace in ipairs(workspaces) do
    local target = "name:" .. workspace.name
    hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({ workspace = target }))
    hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = target, follow = false }))
    if workspace.class then
        hl.window_rule({ match = { class = workspace.class }, workspace = target .. " silent" })
    end
end

-- Keep browsers rendering on hidden workspaces for individual-window PipeWire capture.
-- This costs GPU/power; an application can still throttle itself independently.
hl.window_rule({
    name = "browser-background-rendering",
    match = { class = workspaces[2].class },
    render_unfocused = true,
})

local function exec(key, command, flags)
    hl.bind(key, hl.dsp.exec_cmd(command), flags)
end

exec("SUPER + Return", "ghostty")
exec("SUPER + SHIFT + Return", "hypr-neovide")
exec("SUPER + D", "rofi -show drun")
exec("SUPER + T", "hypr-desktop-action kill-user")
exec("SUPER + SHIFT + T", "hypr-desktop-action kill-root")
exec("SUPER + G", "hypr-desktop-action password")
exec("SUPER + U", "hypr-desktop-action username")
exec("SUPER + O", "hypr-desktop-action otp")
exec("SUPER + SHIFT + S", "hypr-desktop-action screenshot", { release = true })
exec("SUPER + ALT + S", "hypr-desktop-action ocr", { release = true })
exec("SUPER + minus", "brightnessctl set 5%-", { repeating = true })
exec("SUPER + plus", "brightnessctl set +5%", { repeating = true })
exec("SUPER + SHIFT + E", "hypr-desktop-action logout")

hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + SHIFT + space", hl.dsp.window.float())
hl.bind("SUPER + space", hl.dsp.window.cycle_next())
-- There is no parent-container focus; use the last focused window instead.
hl.bind("SUPER + A", hl.dsp.focus({ last = true }))
hl.bind("SUPER + B", hl.dsp.layout("preselect r"))
hl.bind("SUPER + V", hl.dsp.layout("preselect d"))
hl.bind("SUPER + E", hl.dsp.layout("togglesplit"))
-- Hyprland groups approximate i3 tabbed/stacked containers.
hl.bind("SUPER + W", hl.dsp.group.toggle())
hl.bind("SUPER + S", hl.dsp.group.toggle())
exec("SUPER + SHIFT + C", "hyprctl reload")
-- Reload instead of restarting the compositor and terminating Wayland clients.
exec("SUPER + SHIFT + R", "hyprctl reload")

for _, pair in ipairs({
    { "H", "left" },
    { "J", "down" },
    { "K", "up" },
    { "L", "right" },
    { "Left", "left" },
    { "Down", "down" },
    { "Up", "up" },
    { "Right", "right" },
}) do
    hl.bind("SUPER + " .. pair[1], hl.dsp.focus({ direction = pair[2] }))
    hl.bind("SUPER + SHIFT + " .. pair[1], hl.dsp.window.move({ direction = pair[2] }))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

local swapcaps = true
hl.bind("SUPER + SHIFT + A", function()
    swapcaps = not swapcaps
    hl.config({ input = { kb_options = swapcaps and "ctrl:swapcaps" or "" } })
end)
exec("SUPER + P", "hypr-desktop-action touchpad-off")
exec("SUPER + SHIFT + P", "hypr-desktop-action touchpad-on")

exec("XF86AudioRaiseVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+", { locked = true, repeating = true })
exec("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-", { locked = true, repeating = true })
exec("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", { locked = true })
exec("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", { locked = true })

local function reset_binds()
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end

hl.bind("SUPER + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    for _, entry in ipairs({
        { "H", -10, 0 },
        { "J", 0, 10 },
        { "K", 0, -10 },
        { "L", 10, 0 },
        { "Left", -10, 0 },
        { "Down", 0, 10 },
        { "Up", 0, -10 },
        { "Right", 10, 0 },
    }) do
        hl.bind(entry[1], hl.dsp.window.resize({ x = entry[2], y = entry[3], relative = true }), { repeating = true })
    end
    reset_binds()
    hl.bind("SUPER + R", hl.dsp.submap("reset"))
end)

hl.bind("SUPER + BackSpace", hl.dsp.submap("system"))
hl.define_submap("system", "reset", function()
    exec("L", "loginctl lock-session")
    exec("E", "hypr-desktop-action logout")
    exec("R", "systemctl reboot")
    exec("S", "systemctl poweroff")
    reset_binds()
end)

hl.bind("SUPER + I", hl.dsp.submap("bar"))
hl.define_submap("bar", function()
    exec("H", "pkill -SIGUSR1 -x waybar")
    exec("SHIFT + H", "pkill -SIGUSR2 -x waybar")
    reset_binds()
end)

hl.bind("SUPER + M", hl.dsp.submap("workspaces"))
hl.define_submap("workspaces", function()
    hl.bind("H", hl.dsp.workspace.move({ monitor = "l" }))
    hl.bind("L", hl.dsp.workspace.move({ monitor = "r" }))
    reset_binds()
end)

hl.bind("SUPER + C", hl.dsp.submap("mouse"))
hl.define_submap("mouse", function()
    for _, entry in ipairs({ { "H", -1, 0 }, { "J", 0, 1 }, { "K", 0, -1 }, { "L", 1, 0 } }) do
        exec(entry[1], "ydotool mousemove -- " .. (entry[2] * 200) .. " " .. (entry[3] * 200), { repeating = true })
        exec(
            "SHIFT + " .. entry[1],
            "ydotool mousemove -- " .. (entry[2] * 18) .. " " .. (entry[3] * 18),
            { repeating = true }
        )
    end
    exec("I", "ydotool click 0xC0")
    exec("SHIFT + I", "ydotool click 0xC1")
    exec("SHIFT + space", "ydotool click 0xC1")
    exec("O", "ydotool mousemove --wheel -- 0 1", { repeating = true })
    exec("P", "ydotool mousemove --wheel -- 0 -1", { repeating = true })
    for _, key in ipairs({ "space", "Return" }) do
        hl.bind(key, function()
            hl.dispatch(hl.dsp.exec_cmd("ydotool click 0xC0"))
            hl.dispatch(hl.dsp.submap("reset"))
        end)
    end
    hl.bind("C", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
