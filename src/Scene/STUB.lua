
require("src/State")
require("src/Util")
require("src/Bind")
require("src/Scene")
require("src/Camera")
require("src/AudioManager")
require("src/FieldAnimator")
require("src/Animator")
require("src/AssetLoader")
require("src/Asset")

local M = def_module("STUBScene", {
	bind_table = nil,
	bind_group = nil,

	-- Singleton
	--[[
	__initialized = false,
	instance = nil,
	impl = nil
	--]]
})

M.data.bind_table = Bind.redefine_group(M.data.bind_table, {
	["escape"] = {
		on_release = true,
		passthrough = false,
		handler = function(_, _, _, _)
			Event.quit()
		end
	},
})

-- class Impl

M.Impl = class(M.Impl)

function M.Impl:__init()
	-- TODO: INITIALIZE
end

function M.Impl:notify_pushed()
	-- TODO: PUSH-INIT
end

function M.Impl:notify_became_top()
end

function M.Impl:notify_popped()
	-- TODO: POP-DEINIT
end

function M.Impl:focus_changed(focused)
	if not State.pause_lock then
		Core.pause(not focused)
	end
end

function M.Impl:bind_gate(bind, ident, dt, kind)
	return not State.paused
end

function M.Impl:update(dt)
	if not State.paused then
		-- TODO: UPDATE THE THINGS
	end
end

function M.Impl:render()
	Camera.lock()

	-- TODO: RENDER ALL THE THINGS

	Camera.unlock()
end

-- STUBScene interface

-- Instantiable

set_functable(M,
	function(_, transparent)
		if not M.data.bind_group then
			M.data.bind_group = Bind.Group(M.data.bind_table)
		end

		return Scene(M.Impl(), M.data.bind_group, transparent)
	end
)

-- Singleton
--[[

function M.init(_)
	assert(not M.data.__initialized)
	if not M.data.bind_group then
		M.data.bind_group = Bind.Group(M.data.bind_table)
	end

	M.data.instance = Scene(M.Impl(), M.data.bind_group, false)
	M.data.impl = M.data.instance.impl
	M.data.__initialized = true

	return M.data.instance
end

function M.get_instance()
	return M.data.instance
end

--]]

return M
