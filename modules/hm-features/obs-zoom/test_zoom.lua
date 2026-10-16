-- Run with `lua modules/hm-features/obs-zoom/test_zoom.lua` from the repo root.
-- OBS API stub verifies crop/scale restoration without a running OBS instance.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

local function assign(destination, source)
	for key, value in pairs(source) do
		destination[key] = copy(value)
	end
end

local original = { bounds_type = 0, rot = 0, scale = { x = 1, y = 1 }, pos = { x = 100, y = 200 }, alignment = 5 }
local original_crop = { left = 0, top = 0, right = 0, bottom = 0 }
local item = { info = copy(original), crop = copy(original_crop) }
local scene = { name = "Scene" }
local callback
local snapshot = "1 0.5 0.5 1\n"
local now = 0
local item_refs = 0
local scene_refs = 0

obslua = {
	OBS_BOUNDS_NONE = 0,
	LOG_WARNING = 1,
	obs_transform_info = function()
		return {}
	end,
	obs_sceneitem_crop = function()
		return {}
	end,
	obs_scene_from_source = function(source)
		return source
	end,
	obs_scene_find_source = function(_, name)
		return name == "Capture" and item or nil
	end,
	obs_sceneitem_get_info = function(target, info)
		assign(info, target.info)
	end,
	obs_sceneitem_get_crop = function(target, crop)
		assign(crop, target.crop)
	end,
	obs_sceneitem_set_info = function(target, info)
		target.info = copy(info)
	end,
	obs_sceneitem_set_crop = function(target, crop)
		target.crop = copy(crop)
	end,
	obs_sceneitem_get_source = function()
		return {}
	end,
	obs_source_get_width = function()
		return 1920
	end,
	obs_source_get_height = function()
		return 1080
	end,
	obs_sceneitem_addref = function()
		item_refs = item_refs + 1
	end,
	obs_sceneitem_release = function()
		item_refs = item_refs - 1
	end,
	obs_source_get_ref = function(source)
		scene_refs = scene_refs + 1
		return source
	end,
	obs_source_release = function()
		scene_refs = scene_refs - 1
	end,
	obs_source_get_name = function(source)
		return source.name
	end,
	obs_frontend_get_current_scene = function()
		scene_refs = scene_refs + 1
		return scene
	end,
	os_gettime_ns = function()
		return now * 1e9
	end,
	obs_data_get_string = function(settings, key)
		return settings[key]
	end,
	obs_data_get_double = function(settings, key)
		return settings[key]
	end,
	timer_add = function(fn)
		callback = fn
	end,
	timer_remove = function(fn)
		assert(callback == fn)
	end,
	script_log = function() end,
}

local real_open = io.open
io.open = function()
	return {
		read = function()
			return snapshot
		end,
		close = function() end,
	}
end
local real_getenv = os.getenv
os.getenv = function()
	return "/runtime"
end

dofile("modules/hm-features/obs-zoom/zoom.lua")
script_update({ source = "Capture", zoom = 2 })
script_load({})
callback()
assert(item.crop.left == 480 and item.crop.right == 480)
assert(item.crop.top == 270 and item.crop.bottom == 270)
assert(item.info.scale.x == 2 and item.info.scale.y == 2)
assert(item.info.pos.x == 100 and item.info.pos.y == 200)

snapshot = "1 0 1 2\n"
callback()
assert(item.crop.left == 0 and item.crop.right == 960)
assert(item.crop.top == 540 and item.crop.bottom == 0)

-- Dead bridge, even with an enabled snapshot, restores the original transform.
now = 2
callback()
assert(item.crop.left == 0 and item.crop.bottom == 0)
assert(item.info.scale.x == 1 and item.info.scale.y == 1)
assert(item_refs == 0 and scene_refs == 0)

snapshot = "1 0.5 0.5 3\n"
callback()
assert(item.info.scale.x == 2)
snapshot = "0 0.5 0.5 4\n"
callback()
assert(item.info.scale.x == 1 and item_refs == 0 and scene_refs == 0)

-- Existing crops are respected and exactly restored on script unload.
item.crop = { left = 100, right = 100, top = 40, bottom = 40 }
snapshot = "1 0.5 0.5 5\n"
callback()
assert(item.crop.left == 530 and item.crop.right == 530)
script_unload()
assert(item.crop.left == 100 and item.crop.right == 100)
assert(item.crop.top == 40 and item.crop.bottom == 40)
assert(item.info.scale.x == 1 and item_refs == 0 and scene_refs == 0)

io.open = real_open
os.getenv = real_getenv
print("OBS zoom tests passed")
