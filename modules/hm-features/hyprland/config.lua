-- Custom callbacks complement Home Manager's declarative settings/bindings.
-- The writable nwg-displays layout may not exist yet during activation.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local monitors = io.open(config_home .. "/hypr/monitors.lua", "r")
if monitors then
    monitors:close()
    require("monitors")
else
    require("monitor-defaults")
end
require("user")

hl.on("hyprland.start", function()
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("dunst")
    hl.exec_cmd('test ! -f "$HOME/pictures/wallpaper.jpg" || swaybg -i "$HOME/pictures/wallpaper.jpg" -m fill')
end)

local function exec(key, command, flags)
    flags = flags or {}
    flags.description = flags.description or command
    hl.bind(key, hl.dsp.exec_cmd(command), flags)
end

hl.bind("SUPER + E", function()
    local window = hl.get_active_window()
    if window and window.group then
        hl.dispatch(hl.dsp.group.toggle({ window = window }))
    else
        hl.dispatch(hl.dsp.layout("togglesplit"))
    end
end, { description = "Toggle split / toggle window group" })
-- Dwindle has no i3 parent containers: tab the workspace's tiled windows.
-- Repeated presses are idempotent; Mod+E returns the group to split tiling.
local function tab_workspace()
    local window = hl.get_active_window()
    if not window or window.floating then
        return
    end
    local windows = hl.get_windows({ workspace = window.workspace, floating = false, mapped = true })
    if window.group and window.group.size == #windows then
        return
    end
    -- Directional moves transfer one window, not an entire existing group.
    -- Dissolve the workspace's old groups before collecting into one target.
    for _, candidate in ipairs(windows) do
        if candidate.group then
            hl.dispatch(hl.dsp.group.toggle({ window = candidate }))
        end
    end
    hl.dispatch(hl.dsp.group.toggle({ window = window }))
    for _ = 1, #windows do
        local size = window.group and window.group.size or 1
        for _, candidate in ipairs(windows) do
            if not candidate.group then
                for _, direction in ipairs({ "right", "left", "up", "down" }) do
                    hl.dispatch(hl.dsp.window.move({ window = candidate, into_group = direction }))
                    if candidate.group then
                        break
                    end
                end
            end
        end
        if (window.group and window.group.size or 1) == size then
            break
        end
    end
    hl.dispatch(hl.dsp.focus({ window = window }))
end
hl.bind("SUPER + W", tab_workspace, { description = "Tab workspace windows" })

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
    hl.bind("SUPER + " .. pair[1], function()
        local window = hl.get_active_window()
        if window and window.group then
            hl.dispatch((pair[2] == "left" or pair[2] == "up") and hl.dsp.group.prev() or hl.dsp.group.next())
        else
            hl.dispatch(hl.dsp.focus({ direction = pair[2] }))
        end
    end, { description = "Focus " .. pair[2] .. " / cycle group" })
    hl.bind("SUPER + SHIFT + " .. pair[1], function()
        local window = hl.get_active_window()
        if window and window.group then
            hl.dispatch(hl.dsp.group.move_window({ forward = pair[2] == "right" or pair[2] == "down" }))
        else
            hl.dispatch(hl.dsp.window.move({ direction = pair[2] }))
        end
    end, { description = "Move window " .. pair[2] .. " / reorder group" })
end

local swapcaps = true
hl.bind("SUPER + SHIFT + A", function()
    swapcaps = not swapcaps
    hl.config({ input = { kb_options = swapcaps and "ctrl:swapcaps" or "" } })
end, { description = "Toggle Caps/Ctrl swap" })

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
        end, { description = "Click and exit mouse mode" })
    end
    hl.bind("C", hl.dsp.submap("reset"), { description = "Exit mouse mode" })
    hl.bind("Escape", hl.dsp.submap("reset"), { description = "Exit mouse mode" })
end)
