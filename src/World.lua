
require("src/Util")
require("src/Tile")
require("src/Entity")

local M = def_module_unit("World", {})

M.LayerID = {
	bg = 1,
	fg = 2,
	og = 3,
}

-- class Unit

M.Unit = class(M.Unit)

function M.Unit:__init(spec)
	type_assert(spec, "table")

	self.spec = spec
	self.gravity = Vec2(1, 1)
	-- y, x
	self.layers = {}
	table.insert(self.layers, World.LayerID.bg, Tile.Layer())
	table.insert(self.layers, World.LayerID.fg, Tile.Layer())
	table.insert(self.layers, World.LayerID.og, Tile.Layer())
	self.entities = {}
	self.actors = {}

	if self.spec then
		for id, layer in pairs(self.layers) do
			for y, row in pairs(self.spec.layers[id]) do
				for x, tile in pairs(row) do
					layer:set_tile(x, y, tile)
				end
			end
		end
		for _, entity in pairs(self.spec.entities) do
			self:add_entity(Entity(entity[1], entity[2], entity[3]))
		end
	end
end

function M.Unit:get_layer(id)
	assert(id >= World.LayerID.bg and id <= World.LayerID.og)
	return self.layers[id]
end

function M.Unit:add_entity(entity)
	table.insert(self.entities, entity)
end

function M.Unit:add_actor(actor)
	table.insert(self.actors, actor)
end

function M.Unit:find_entity(name)
	for _, entity in pairs(self.entities) do
		if entity.name == name then
			return entity
		end
	end
	return nil
end

function M.Unit:update(dt)
	for _, entity in pairs(self.entities) do
		entity:update(self, dt)
	end
	for _, actor in pairs(self.actors) do
		actor:update(self, dt)
	end
end

function M.Unit:render()
	if State.gfx_debug then
		Gfx.setBlendMode("alpha")
	end
	for _, actor in pairs(self.actors) do actor:render(self, 1) end
	for _, entity in pairs(self.entities) do entity:render(self, 1) end
	if not State.gfx_debug then
		Gfx.setBlendMode("subtractive")
	else
		Gfx.setBlendMode("alpha")
	end
	self.layers[World.LayerID.bg]:render()
	self.layers[World.LayerID.fg]:render(State.gfx_debug)
	for _, actor in pairs(self.actors) do actor:render(self, 2) end
	for _, entity in pairs(self.entities) do entity:render(self, 2) ; entity:render(self) end
	for _, actor in pairs(self.actors) do actor:render(self) end
	if not State.gfx_debug then
		Gfx.setBlendMode("subtractive")
	else
		Gfx.setBlendMode("alpha")
	end
	self.layers[World.LayerID.og]:render()
end

return M
