-- Handy's Wayland hotkeys belong to the compositor, not its X11 global grabs.
local handy_held = false
local handy_toggle = hl.dsp.exec_cmd("handy --toggle-transcription")

local function handy_stop()
	if not handy_held then
		return
	end
	handy_held = false
	handy_toggle()
end

hl.bind("ALT + space", function()
	if handy_held then
		return
	end
	handy_held = true
	handy_toggle()
end, { description = "Hold to dictate with Handy" })

-- Ignore modifiers so releasing Alt before Space still stops recording.
-- Guard the callback so ordinary Space/Alt releases do not toggle Handy.
for _, key in ipairs({ "space", "Alt_L", "Alt_R" }) do
	hl.bind(key, handy_stop, {
		description = "Stop held Handy dictation",
		release = true,
		ignore_mods = true,
		non_consuming = true,
		transparent = true,
		submap_universal = true,
	})
end
