
require("src/State")
require("src/Util")
require("src/Math")
require("src/Bind")
require("src/Scene")
require("src/AudioManager")
require("src/Animator")
require("src/Asset")
require("src/AssetLoader")

require("src/Scene/Main")
require("src/Scene/Menu")

local M = def_module("Core", {
	bind_table = nil,
	display_size = Vec2(),
	display_size_half = Vec2()
})

M.data.bind_table = Bind.redefine_group(M.data.bind_table, {
-- System
	["pause"] = {
		on_release = true,
		system = true,
		handler = function(_, _, _, _)
			local paused = not State.pause_lock
			State.pause_lock = false
			Core.pause(paused)
			State.pause_lock = paused
		end
	}
})

function M.bind_gate(bind, ident, dt, kind)
	if State.paused then
		return false
	end
	return Scene.bind_gate(bind, ident, dt, kind)
end

function M.update_display_size(width, height)
	Core.display_size = Vec2(width, height)
	Core.display_size_half = Core.display_size * 0.5
end

function M.init(args)
	M.time_sampler = 0

	-- Ensure debug is enabled for initialization
	local debug_mode_temp = false
	if not State.gen_debug then
		debug_mode_temp = true
		State.gen_debug = true
	end

	Core.update_display_size(Gfx.getWidth(), Gfx.getHeight())

	if not debug_mode_temp then
		M.data.bind_table["f1"] = {
			on_release = true,
			system = true,
			handler = function(_, _, _, _)
				State.gen_debug = not State.gen_debug
				if State.gen_debug then
					log("debug mode enabled")
				else
					log("debug mode disabled")
				end
			end
		}
		M.data.bind_table["f5"] = {
			on_release = true,
			system = true,
			handler = function(_, _, _, _)
				State.gfx_debug = not State.gfx_debug
				if State.gfx_debug then
					log("graphics debug mode enabled")
				else
					log("graphics debug mode disabled")
				end
			end
		}
		M.data.bind_table["f6"] = {
			on_release = true,
			system = true,
			handler = function(_, _, _, _)
				State.gfx_debug_cross = not State.gfx_debug_cross
				if State.gfx_debug_cross then
					log("graphics crosshair debug mode enabled")
				else
					log("graphics crosshair debug mode disabled")
				end
			end
		}
	end

	Gfx.setDefaultFilter("nearest", "nearest", 0)

	-- system initialization
	Util.init()
	Bind.init(M.data.bind_table, Core.bind_gate, true)

	-- assets
	AssetLoader.load("asset/", Asset.desc_root, Asset)
	AudioManager.init(Asset.sound)

	-- more systems
	Animator.init(Asset.anim)
	Scene.init()

	-- default rendering state
	Gfx.setFont(Asset.font.main)
	Gfx.setLineWidth(2.0)
	Gfx.setColor(255,255,255, 255)
	Gfx.setBackgroundColor(0,0,0, 255)

	MainScene.init(args)
	Scene.push(MenuScene())

	-- Ensure debug is disabled after initialization
	if debug_mode_temp then
		State.gen_debug = false
	end
end

function M.deinit()
	Scene.clear()
end

function M.quit()
	Event.quit()
end

function M.on_quit()
	Core.deinit()
end

function M.pause(paused)
	if not State.pause_lock then
		if not Scene.on_pause_changed(paused) then
			return
		end
		State.paused = paused
		if State.paused then
			AudioManager.pause()
		else
			AudioManager.resume()
		end
	end
end

function M.focus_changed(focused)
	if not State.pause_lock then
		Core.pause(not focused)
	end
end

function M.display_resized(width, height)
	Core.update_display_size(width, height)
end

function M.update(dt)
	M.time_sampler = M.time_sampler + dt
	if true == State.paused then
		Bind.update(0.0)
	else
		Bind.update(dt)
		AudioManager.update(dt)
	end
	Scene.update(dt)
end

function M.render()
	Gfx.setColor(255,255,255, 255)
	Scene.render()

	if State.gfx_debug then
		Gfx.setColor(192,192,192, 200)
		Gfx.rectangle("line", 0.0, 0.0, Core.display_size.x, Core.display_size.y)
	end

	if State.gfx_debug_cross then
		Gfx.setColor(192,192,192, 200)
		-- Vertical
		Gfx.line(Core.display_size_half.x, 0.0, Core.display_size_half.x, Core.display_size.y)
		-- Horizontal
		Gfx.line(0.0, Core.display_size_half.y, Core.display_size.x, Core.display_size_half.y)
	end
end

return M
