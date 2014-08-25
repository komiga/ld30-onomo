
require("src/State")
require("src/Util")
require("src/Bind")
require("src/Scene")
require("src/Asset")

require("src/Scene/Intro")
require("src/Scene/Main")

local M = def_module("MenuScene", {
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
	[{"return", " "}] = {
		on_release = true,
		handler = function(_, _, _, _)
			Scene.push(MainScene.get_instance())
		end
	},
})

-- class Impl

M.Impl = class(M.Impl)

function M.Impl:__init()
	self.started_bgm = false
	self.camera = Camera(Vec2(), 200.0)
	self.world = World(Asset.world.menu)
	self.camera:set_scale(2, 2)
end

function M.Impl:notify_pushed()
	Scene.push(IntroScene(
		Asset.intro_seq,
		Asset.atlas.intro_seq,
		false
	))
end

function M.Impl:notify_became_top()
	if not self.started_bgm then
		self.started_bgm = true
		Asset.music.bgm.source:play()
	end
end

function M.Impl:notify_popped()
end

function M.Impl:bind_gate(bind, ident, dt, kind)
	return not State.paused
end

function M.Impl:on_pause_changed(new_paused)
	return true
end

function M.Impl:update(dt)
	if State.paused then
		return
	end

	self.camera:update(dt)
	self.world:update(dt)
end

function M.Impl:render()
	Gfx.setBlendMode("alpha")
	Gfx.setColor(255,255,255, 255)
	Gfx.print(
		"PRESS\nSPACE",
		Core.display_size_half.x,Core.display_size_half.y + 240
	)
	self.camera:lock()
	Camera.set(self.camera)
	self.world:render()
	self.camera:unlock()
end

-- MenuScene interface

-- Instantiable

set_functable(M,
	function(_, transparent)
		if not M.data.bind_group then
			M.data.bind_group = Bind.Group(M.data.bind_table)
		end
		return Scene(M.Impl(), M.data.bind_group, transparent)
	end
)

return M
