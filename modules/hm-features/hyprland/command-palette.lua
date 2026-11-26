-- Loaded before generated bindings so Lua callbacks and dispatchers are both
-- available to the palette, including bindings from user.lua and submaps.
local original_bind = hl.bind
local actions = {}

hl.bind = function(key, action, options)
    local binding = original_bind(key, action, options)
    if binding then
        actions[binding.arg] = { binding = binding, action = action }
    end
    return binding
end

function dotfiles_run_binding(id, description)
    local entry = actions[id]
    -- Reject removed/disabled bindings and stale selections after a reload.
    if not entry or not entry.binding.enabled or entry.binding.description ~= description then
        return
    end
    hl.dispatch(entry.action)
end

-- Device overrides reset along with this state when the config is reloaded.
local touchpad_enabled = true
function dotfiles_toggle_touchpad(...)
    if select("#", ...) == 0 then
        return
    end
    touchpad_enabled = not touchpad_enabled
    for _, name in ipairs({ ... }) do
        hl.device({ name = name, enabled = touchpad_enabled })
    end
end
