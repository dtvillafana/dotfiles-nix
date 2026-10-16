local obs = obslua
local source_name = ""
local zoom = 2
local active = nil
local last_snapshot = nil
local last_change = 0
local blocked = false

local function restore()
	if active then
		obs.obs_sceneitem_set_crop(active.item, active.crop)
		obs.obs_sceneitem_set_info(active.item, active.info)
		obs.obs_sceneitem_release(active.item)
		obs.obs_source_release(active.scene)
		active = nil
	end
end

local function start(scene_source)
	local scene = obs.obs_scene_from_source(scene_source)
	local item = obs.obs_scene_find_source(scene, source_name)
	if not item then
		return false
	end
	local info = obs.obs_transform_info()
	local crop = obs.obs_sceneitem_crop()
	obs.obs_sceneitem_get_info(item, info)
	obs.obs_sceneitem_get_crop(item, crop)
	if info.bounds_type ~= obs.OBS_BOUNDS_NONE or info.rot ~= 0 or info.scale.x <= 0 or info.scale.y <= 0 then
		obs.script_log(
			obs.LOG_WARNING,
			"Zoom requires an unrotated source with no bounding box. Reset Transform, then Fit to Screen."
		)
		blocked = true
		return false
	end
	local source = obs.obs_sceneitem_get_source(item)
	local width = obs.obs_source_get_width(source)
	local height = obs.obs_source_get_height(source)
	if width <= crop.left + crop.right or height <= crop.top + crop.bottom then
		return false
	end
	obs.obs_sceneitem_addref(item)
	local retained_scene = obs.obs_source_get_ref(scene_source)
	if not retained_scene then
		obs.obs_sceneitem_release(item)
		return false
	end
	active = { item = item, scene = retained_scene, info = info, crop = crop, width = width, height = height }
	return true
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function tick()
	local runtime = os.getenv("XDG_RUNTIME_DIR")
	if not runtime then
		return
	end
	local file = io.open(runtime .. "/obs-hyprland-zoom/snapshot", "r")
	local snapshot = file and file:read("*a") or ""
	if file then
		file:close()
	end
	-- The heartbeat changes even when the pointer does not move.
	local enabled, x, y, heartbeat = snapshot:match("^(%d) ([%d.]+) ([%d.]+) ([%d.]+)")
	local now = obs.os_gettime_ns() / 1e9
	if heartbeat ~= last_snapshot then
		last_snapshot = heartbeat
		last_change = now
	end
	if enabled ~= "1" or now - last_change > 1 then
		restore()
		blocked = false
		return
	end
	if blocked or source_name == "" then
		return
	end
	local scene = obs.obs_frontend_get_current_scene()
	if not scene then
		restore()
		return
	end
	if active and obs.obs_source_get_name(scene) ~= obs.obs_source_get_name(active.scene) then
		restore()
	end
	if not active and not start(scene) then
		obs.obs_source_release(scene)
		return
	end
	obs.obs_source_release(scene)

	local original = active.crop
	local source = obs.obs_sceneitem_get_source(active.item)
	active.width = obs.obs_source_get_width(source)
	active.height = obs.obs_source_get_height(source)
	if active.width <= original.left + original.right or active.height <= original.top + original.bottom then
		restore()
		return
	end
	local width = active.width - original.left - original.right
	local height = active.height - original.top - original.bottom
	local view_width = math.max(1, math.floor(width / zoom))
	local view_height = math.max(1, math.floor(height / zoom))
	local crop = obs.obs_sceneitem_crop()
	crop.left = math.floor(
		clamp(tonumber(x) * active.width - view_width / 2, original.left, active.width - original.right - view_width)
	)
	crop.top = math.floor(
		clamp(
			tonumber(y) * active.height - view_height / 2,
			original.top,
			active.height - original.bottom - view_height
		)
	)
	crop.right = active.width - crop.left - view_width
	crop.bottom = active.height - crop.top - view_height

	-- Keep the original rectangle and alignment; only its visible contents change.
	local info = obs.obs_transform_info()
	obs.obs_sceneitem_get_info(active.item, info)
	info.scale.x = active.info.scale.x * width / view_width
	info.scale.y = active.info.scale.y * height / view_height
	obs.obs_sceneitem_set_crop(active.item, crop)
	obs.obs_sceneitem_set_info(active.item, info)
end

function script_description()
	return "Hyprland mouse-follow zoom. Select the captured window source, then press Super+Shift+Z over that window. Use a Scene Projector, not a Source Projector. See hyprland-zoom.md beside this script."
end

function script_defaults(settings)
	obs.obs_data_set_default_double(settings, "zoom", 2)
end

function script_properties()
	local properties = obs.obs_properties_create()
	local list = obs.obs_properties_add_list(
		properties,
		"source",
		"Window capture source",
		obs.OBS_COMBO_TYPE_LIST,
		obs.OBS_COMBO_FORMAT_STRING
	)
	obs.obs_property_list_add_string(list, "Select a source", "")
	local sources = obs.obs_enum_sources()
	if sources then
		for _, source in ipairs(sources) do
			if obs.obs_source_get_width(source) > 0 then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(list, name, name)
			end
		end
		obs.source_list_release(sources)
	end
	obs.obs_properties_add_float_slider(properties, "zoom", "Zoom factor", 1.1, 5, 0.1)
	return properties
end

function script_update(settings)
	restore()
	blocked = false
	source_name = obs.obs_data_get_string(settings, "source")
	zoom = obs.obs_data_get_double(settings, "zoom")
end

function script_load(settings)
	obs.timer_add(tick, 33)
end

function script_unload()
	obs.timer_remove(tick)
	restore()
end
