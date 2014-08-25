
require("src/Util")
require("src/Math")
require("src/AudioManager")
require("src/Animator")
require("src/Tile")

local M = def_module_unit("Entity", {})

-- class Unit

M.Unit = class(M.Unit)

function M.Unit:__init(name, gx, gy)
	type_assert(name, "string")
	type_assert(gx, "number", true)
	type_assert(gy, "number", true)

	local spec = Asset.entity[name]
	assert(spec)
	self.name = name
	self.anim_name = nil
	self.anim_instance = nil
	if not spec.static then
		self.anim_instance = Animator.Instance(spec.anim_data, 1, Animator.Mode.Stop)
		self.anim_instance.sy = 1
		self.anim_instance.ox = 16
		self.anim_instance.oy = 0
	end

	self.gx = 0
	self.gy = 0
	self.position = Vec2()
	self.accel = 0
	self.accel_dir = 0
	self.speed = Vec2(80, 80)
	self.velocity = Vec2()
	self.target_velocity = Vec2()
	self.orientation = 1
	self.vars = {}
	self:set_anim("idle")
	self:move_grid(gx or 0, gy or 0)
end

function M.Unit:set_anim(anim_name)
	local spec = Asset.entity[self.name]
	type_assert(anim_name, "string")
	if spec.static then
		return
	end
	local prop = spec.anim[anim_name]
	assert(prop)
	self.anim_name = anim_name
	self.anim_instance:reset(prop.index, prop.mode)
end

function M.Unit:set_camera_position(camera, immediate)
	local spec = Asset.entity[self.name]
	local x = self.position.x + 16
	local y = self.position.y + 16 + 32
	if immediate then
		camera:set_position(x, y)
	else
		camera:target(x, y)
	end
end

function M.Unit:move_grid(gx, gy)
	local spec = Asset.entity[self.name]
	self.gx = gx
	self.gy = gy
	self.position.x = self.gx * 32
	self.position.y = self.gy * 32
	if not spec.static then
		self.anim_instance.x = self.position.x + 16
		self.anim_instance.y = self.position.y - spec.height + 32
	end
end

function M.Unit:set_movement_x(dir)
	self.accel_dir = clamp(dir, -1, 1)
end

function M.Unit:set_movement_y(dir)
end

function M.Unit:update_position(world, dt)
	local spec = Asset.entity[self.name]
	self.gx = math.floor((self.position.x + 16) / 32)
	self.gy = math.floor(self.position.y / 32)
	if self.accel ~= 0 or self.accel_dir ~= 0 then
		if self.anim_name ~= "move" and spec.anim["move"] then
			self:set_anim("move")
		end
		local f = self.accel_dir ~= 0 and 1.50 or -1.80
		if self.accel_dir ~= 0 then
			self.target_velocity.x = self.speed.x * self.accel_dir
		else
			self.target_velocity.x = 0
		end
		self.accel = clamp(self.accel + dt * f, 0, 1)
		-- self.velocity.x = Math.lerp(self.velocity.x, self.target_velocity.x, self.accel)
		self.velocity.x = self.target_velocity.x * self.accel
		local x = self.position.x + self.velocity.x * dt
		local gx = math.floor((x + 16) / 32)
		if not world or not world.layers[World.LayerID.fg]:get_tile(gx, self.gy) then
			self.position.x = x
			self.gx = gx
		else
			self.accel = 0
			self.velocity.x = 0
		end
	elseif self.anim_name == "move" then
		self:set_anim("idle")
	end
	if not spec.static then
		self.anim_instance.x = self.position.x + 16
		self.anim_instance.y = self.position.y - spec.height + 32
	end
end

function M.Unit:update(world, dt)
	local spec = Asset.entity[self.name]
	self:update_position(world, dt)
	if not spec.static then
		local sdt = dt * (spec.anim[self.anim_name].passive and 1 or self.accel)
		self.anim_instance:update(sdt)
	end
end

function M.Unit:render(world, prepass)
	local spec = Asset.entity[self.name]
	if prepass then
		if not spec.light then
			return
		end
		local af = 5 * math.sin(4 * Core.time_sampler)
		local sf = 0.005 * math.cos(4 * Core.time_sampler)
		if prepass == 1 then
			local sx = spec.light.sx + sf
			local sy = spec.light.sy + sf
			Gfx.setBlendMode(self.vars.rune_activated and "additive" or spec.light.blend_mode)
			Gfx.setColor(235,235,255, 80 + af)
			Gfx.draw(Asset.atlas.light.tex,
				Asset.atlas.light[spec.light.kind],
				self.position.x - sx * 128 + 16,
				self.position.y - sy * 256 + 96,
				0, sx, sy
			)
		elseif prepass == 2 then
			local sx = 0.15 + sf
			local sy = spec.height / 64 * 0.55 + sf + spec.light.inner_height_add
			Gfx.setBlendMode("additive")
			Gfx.setColor(235,235,255, spec.light.inner_power + 0.8 * af)
			Gfx.draw(Asset.atlas.light.tex,
				Asset.atlas.light[spec.light.kind],
				self.position.x - sx * 128 + 16,
				self.position.y - sy * 256 + 96 - 48,
				0, sx, sy
			)
		end
	else
		Gfx.setBlendMode(spec.blend_mode)
		Gfx.setColor(255,255,255, 255)
		if spec.static then
			local atlas = Asset.atlas[spec.static.atlas]
			Gfx.draw(
				atlas.tex,
				atlas[spec.static.sidx],
				self.position.x,
				self.position.y - spec.height + 32
			)
		else
			self.anim_instance.sx = self.orientation
			self.anim_instance:render()
		end
	end
end

return M
