
Timer = love.timer
Event = love.event
Gfx = love.graphics
Sfx = love.audio
Phys = love.physics

HID = {
	Mouse = love.mouse,
	Keyboard = love.keyboard
}

require("src/State")
require("src/Util")
require("src/Math")
require("src/Core")

HID.Mouse.pos = Vec2()

local lurker = nil
local lovebird = nil

local function module_reload(path)
	local modname = lurker.modname(path)
	local mod = require(modname)
	if "table" == type(mod) and mod.module_reload then
		mod.module_reload()
	end
end

if State.auto_reload then
	lurker = require("dep/lurker/lurker")
	lurker.interval = 1.0
	lurker.postswap = module_reload
end

if State.enable_lovebird then
	lovebird = require("dep/lovebird/lovebird")
end

function love.load(argv)
	Core.init(argv)
end

function love.update(dt)
	if State.auto_reload and lurker then
		lurker.update()
	end
	if State.enable_lovebird and lovebird then
		lovebird.update()
	end
	Core.update(dt)
end

function love.draw()
	Gfx.clear()
	Gfx.origin()
	Core.render()
	Gfx.present()
end

function love.quit()
	Core.on_quit()
	return false
end

function love.focus(f)
	Core.focus_changed(f)
end

function love.resize(width, height)
	Core.display_resized(width, height)
end

-- Replace love.run() to use fixed timestep
function love.run()
	-- Seed RNG
	math.randomseed(os.time())
	math.random()
	math.random()

	love.load(love.arg)

    local update_freq = 1.0 / 60.0
    local render_freq = 1 / 60.0
    local render_freq_low = 1 / 15.0
	local update_time = 0
	local render_time = 0
	local current_time = 0
	local base_time = Timer.getTime()
	local do_render = false
	while true do
	    current_time = Timer.getTime() - base_time
		while update_time <= current_time do
			Event.pump()
			for event, a, b, c, d in Event.poll() do
				if "quit" == event then
					if not love.quit() then
						if Sfx then
							Sfx.stop()
						end
						return
					end
				end
				love.handlers[event](a, b, c, d)
			end
			Event.clear()

			HID.Mouse.pos:set(HID.Mouse.getX(), HID.Mouse.getY())
			love.update(update_freq)
			update_time = current_time + update_freq
		end
		if render_time <= current_time then
			render_time = current_time + ternary(love.window.hasFocus(), render_freq, render_freq_low)
			do_render = true
		end

		if do_render then
			do_render = false
			love.draw()
		end
		Timer.sleep(0.001)
	end
end
