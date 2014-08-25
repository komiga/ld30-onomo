
require("src/State")
require("src/Util")
require("src/Math")
require("src/Bind")
require("src/Scene")
require("src/Camera")
require("src/AudioManager")
require("src/Animator")
require("src/AssetLoader")
require("src/Asset")

require("src/World")
require("src/Entity")

local M = def_module("MainScene", {
	__initialized = false,

	bind_table = nil,
	bind_group = nil,
	impl = nil,
	instance = nil
})

local function tile_id_by_index(index)
	local i = 1
	for id, v in pairs(Asset.tileset.prop) do
		if i == index then
			return id
		end
		i = i + 1
	end
	return nil
end

M.data.bind_table = Bind.redefine_group(M.data.bind_table, {
	["escape"] = {
		on_release = true,
		passthrough = false,
		handler = function(_, _, _, _)
			Scene.pop(MainScene.get_instance())
		end
	},
	["e"] = {
		on_release = true,
		handler = function(_, _, _, _)
			if not State.gen_debug then
				return
			end
			local scene = MainScene.get_impl()
			State.edit_mode = not State.edit_mode
			State.gfx_debug = State.edit_mode
			local focus_entity = scene.current.char
			if State.edit_mode then
				scene.edit_entity:move_grid(
					scene.current.char.gx,
					scene.current.char.gy
				)
				focus_entity = scene.edit_entity
			end
			scene.current.char:set_movement_x(0)
			scene.current.char:set_movement_y(0)
			focus_entity:set_camera_position(scene.current.camera, true)
		end
	},
	["s"] = {
		on_release = true,
		handler = function(_, _, _, _)
			if not State.gen_debug then
				return
			end
			local write_world = function(world)
				io.write("\t\tlayers = {\n")
				for id, layer in pairs(world.layers) do
					io.write("\t\t\t[" .. tostring(id) .. "] = {")
					for y, row in pairs(layer.rows) do
						io.write("[" .. tostring(y) .. "] = {")
						for x, tile in pairs(row) do
							local tile_id = tile
							io.write("[" .. tostring(x) .. "]=" .. tostring(tile_id) .. ",")
						end
						io.write("}, ")
					end
					io.write("},\n")
				end
				io.write("\t\t},\n")
				io.write("\t\tentities = {\n")
				for _, entity in pairs(world.entities) do
					io.write("\t\t\t{\"" .. entity.name .. "\"," .. tostring(entity.gx) .. "," .. tostring(entity.gy) .. "},\n")
				end
				io.write("\t\t},\n")
			end
			local scene = MainScene.get_impl()
			log("top:")
			write_world(scene.side.top.world)
			log("bottom:")
			write_world(scene.side.bot.world)
		end
	},
	[" "] = {
		on_press = true,
		handler = function(_, _, _, _)
			local scene = MainScene.get_impl()
			scene:switch_world()
		end
	},
	["q"] = {
		on_press = true,
		on_active = true,
		handler = function(_, _, _, _)
			if not State.edit_mode then
				return
			end
			local scene = MainScene.get_impl()
			local layer = scene.current.world:get_layer(scene.delete_layer)
			layer:set_tile(scene.edit_entity.gx, scene.edit_entity.gy, nil)
		end
	},
	["w"] = {
		on_press = true,
		on_active = true,
		handler = function(_, _, _, _)
			if not State.edit_mode then
				return
			end
			local scene = MainScene.get_impl()
			local layer = scene.current.world:get_layer(Asset.tileset.prop[scene.edit_tile].layer)
			layer:set_tile(scene.edit_entity.gx, scene.edit_entity.gy, scene.edit_tile)
		end
	},
	[{"1", "3"}] = {
		on_press = true,
		handler = function(ident, _, _, _)
			if not State.edit_mode then
				return
			end
			local scene = MainScene.get_impl()
			scene.edit_tile_index = clamp(
				scene.edit_tile_index + ("1" == ident and -1 or 1),
				1, Asset.tileset.count
			)
			scene.edit_tile = tile_id_by_index(scene.edit_tile_index)
		end
	},
	[{"a", "d"}] = {
		on_press = true,
		handler = function(ident, _, _, _)
			if not State.edit_mode then
				return
			end
			local scene = MainScene.get_impl()
			scene.delete_layer = clamp(
				scene.delete_layer + ("a" == ident and -1 or 1),
				World.LayerID.bg, World.LayerID.og
			)
		end
	},
	[{"up", "down", "left", "right"}] = {
		on_press = true,
		on_active = true,
		on_release = true,
		data = {
			keys = {
				["up"]		= {cooldown = 0, vec = Vec2( 0, -1)},
				["down"]	= {cooldown = 0, vec = Vec2( 0,  1)},
				["left"]	= {cooldown = 0, vec = Vec2(-1,  0)},
				["right"]	= {cooldown = 0, vec = Vec2( 1,  0)},
			}
		},
		handler = function(ident, dt, kind, bind)
			local scene = MainScene.get_impl()
			local key = bind.data.keys[ident]
			local vec = Vec2(key.vec.x, scene.current == scene.side.top and key.vec.y or -key.vec.y)
			if not State.edit_mode then
				if Bind.Kind.Press == kind then
					if vec.x ~= 0 then
						scene.current.char.orientation = vec.x
					end
					if vec.x ~= 0 then scene.current.char:set_movement_x(vec.x) end
					if vec.y ~= 0 then scene.current.char:set_movement_y(vec.y) end
				elseif Bind.Kind.Release == kind then
					if vec.x ~= 0 then scene.current.char:set_movement_x(0) end
					if vec.y ~= 0 then scene.current.char:set_movement_y(0) end
				end
			else
				if Bind.Kind.Active == kind then
					key.cooldown = max(0, key.cooldown - dt)
					if key.cooldown > 0 then
						return
					end
				end
				if Bind.Kind.Release ~= kind then
					scene.edit_entity.gx = scene.edit_entity.gx + vec.x
					scene.edit_entity.gy = scene.edit_entity.gy + vec.y
					scene.edit_entity.position.x = scene.edit_entity.gx * 32
					scene.edit_entity.position.y = scene.edit_entity.gy * 32
					scene.edit_entity:update_position(nil, 0)
				end
				key.cooldown = Bind.has_modifiers_any("lshift", "rshift") and 0.020 or 0.080
			end
		end
	},
})

-- class Impl

M.Impl = class(M.Impl)

function M.Impl:__init()
	self.edit_entity = Entity("edit")
	self.edit_tile_index = 1
	self.edit_tile = tile_id_by_index(self.edit_tile_index)
	self.delete_layer = World.LayerID.fg

	self.side = {}
	self.side.top = {
		camera = Camera(Vec2(), 200.0),
		world = World(Asset.world.t_start),
		char = Entity("char_top"),
	}
	self.side.bot = {
		camera = Camera(Vec2(), 400.0),
		world = World(Asset.world.b_start),
		char = Entity("char_bot"),
	}
	self.side.top.camera:set_scale(2, 2)
	self.side.top.world:add_actor(self.side.top.char)
	self.side.top.char:set_camera_position(self.side.top.camera, true)
	self.side.top.char.speed.x = 70 -- 600
	self.side.top.char.speed.y = 70 -- 600

	self.side.bot.camera:set_scale(2, -2)
	self.side.bot.world:add_actor(self.side.bot.char)
	self.side.bot.char.orientation = -1
	self.side.bot.char:set_camera_position(self.side.bot.camera, true)
	self.side.bot.char.speed.x = 120 -- 600
	self.side.bot.char.speed.y = 120 -- 600

	self.current = self.side.top
	self.opposite = self.side.bot
end

function M.Impl:notify_pushed()
end

function M.Impl:notify_became_top()
end

function M.Impl:notify_popped()
end

function M.Impl:bind_gate(bind, ident, dt, kind)
	--if "escape" == ident then
	--	return true
	--end
	return not State.paused
end

function M.Impl:on_pause_changed(new_paused)
	if not State.gen_debug then
		Scene.pop(MainScene.get_instance())
	end
	return not State.gen_debug
end

function M.Impl:switch_world()
	local previous = self.current
	self.current.char:set_movement_x(0)
	self.current.char:set_movement_y(0)
	self.current = self.opposite
	self.opposite = previous
	self.edit_entity:move_grid(
		self.current.char.gx,
		self.current.char.gy
	)
end

function M.Impl:_check_runes(side, opposite)
	for _, entity in pairs(side.world.entities) do
		local entity_spec = Asset.entity[entity.name]
		if
			entity_spec.rune and
			entity.gx == side.char.gx and
			entity.gy == side.char.gy
		then
			AudioManager.spawn(
				Asset.sound[entity_spec.rune.sound_name],
				entity.position.x,
				entity.position.y
			)
			local corune_entity = opposite.world:find_entity(entity_spec.rune.corune)
			if corune_entity then
				local corune_entity_spec = Asset.entity[corune_entity.name]
				local sound_data = Asset.sound[corune_entity_spec.rune.sound_name]
				if #AudioManager.get_bucket(sound_data).active > 0 then
					entity.vars.rune_activated = true
					corune_entity.vars.rune_activated = true
				end
			end
		end
	end
end

function M.Impl:update(dt)
	if State.paused then
		return
	end

	local top_gx = self.side.top.char.gx
	local top_gy = self.side.top.char.gy
	local bot_gx = self.side.bot.char.gx
	local bot_gy = self.side.bot.char.gy

	self.side.top.camera:update(dt)
	self.side.top.world:update(dt)
	self.side.bot.camera:update(dt)
	self.side.bot.world:update(dt)

	if self.side.top.char.gx ~= top_gx or self.side.top.char.gy ~= top_gy then
		self:_check_runes(self.side.top, self.side.bot)
	end
	if self.side.bot.char.gx ~= bot_gx or self.side.bot.char.gy ~= bot_gy then
		self:_check_runes(self.side.bot, self.side.top)
	end

	local focus_entity = self.current.char
	if State.edit_mode then
		focus_entity = self.edit_entity
		self.edit_entity:update(self.current.world, dt)
	end
	focus_entity:set_camera_position(self.current.camera, true--[[State.edit_mode--]])
	self.opposite.char:set_camera_position(self.opposite.camera, true)
end

function M.Impl:render()
	Gfx.setColor(255, 255, 255, 255)

	Camera.set(self.side.top.camera)
	Gfx.setScissor(0, 0, Core.display_size.x, Core.display_size_half.y)
	self.side.top.camera:lock()
	self.side.top.world:render()
	if State.edit_mode and self.current == self.side.top then
		Gfx.setBlendMode("alpha")
		self.edit_entity:render()
	end
	self.side.top.camera:unlock()
	Gfx.setScissor()

	Camera.set(self.side.bot.camera)
	self.side.bot.camera:lock()
	Gfx.setScissor(0, Core.display_size_half.y, Core.display_size.x, Core.display_size_half.y)
	self.side.bot.world:render()
	if State.edit_mode and self.current == self.side.bot then
		Gfx.setBlendMode("alpha")
		self.edit_entity:render()
	end
	Gfx.setScissor()
	self.side.bot.camera:unlock()

	Gfx.push()
	Gfx.setBlendMode("alpha")
	Gfx.setColor(70, 70, 70, 255)
	Gfx.line(0, Core.display_size_half.y, Core.display_size.x, Core.display_size_half.y)
	if State.edit_mode then
		Gfx.setColor(255, 255, 255, 255)
		Gfx.scale(2, 2)
		local layer_names = {"bg", "fg", "og"}
		local prop = Asset.tileset.prop[self.edit_tile]
		Gfx.print(layer_names[Asset.tileset.prop[self.edit_tile].layer], prop.width + 16, 16)
		Gfx.print(layer_names[self.delete_layer], prop.width + 48, 16)
		Gfx.translate(0, prop.height - 32)
		Tile.render(self.edit_tile, 0, 0)
	end
	Gfx.pop()
	if State.gfx_debug then
		Gfx.setColor(255, 255, 255, 255)
		Gfx.print(tostring(self.side.top.char.gx) .. ", " .. tostring(self.side.top.char.gy), 180, 100)
		Gfx.print(tostring(self.side.bot.char.gx) .. ", " .. tostring(self.side.bot.char.gy), 180, 120)
		Gfx.print(tostring(self.edit_entity.gx) .. ", " .. tostring(self.edit_entity.gy), 180, 140)
	end
end

-- MainScene interface

function M.init(_)
	assert(not M.data.__initialized)
	if not M.data.bind_group then
		M.data.bind_group = Bind.Group(M.data.bind_table)
	end
	Camera.init(Vec2(), 512)
	Camera.set_scale(2)

	M.data.instance = Scene(M.Impl(), M.data.bind_group, false)
	M.data.impl = M.data.instance.impl
	M.data.__initialized = true

	return M.data.instance
end

function M.get_instance()
	return M.data.instance
end

function M.get_impl()
	return M.data.instance.impl
end

return M
