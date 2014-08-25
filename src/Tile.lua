
require("src/Util")

local M = def_module("Tile", {})

-- class Layer

M.Layer = class(M.Layer)

function M.Layer:__init()
	self.rows = {}
end

function M.Layer:set_tile(x, y, tile)
	if not self.rows[y] then
		self.rows[y] = {}
	end
	self.rows[y][x] = tile
end

function M.Layer:get_tile(x, y)
	if self.rows[y] then
		return self.rows[y][x]
	end
	return nil
end

function M.Layer:render(debug)
	for y, row in pairs(self.rows) do
		for x, tile in pairs(row) do
			Tile.render(tile, x, y)
			if debug then
				Gfx.setColor(180,0,180, 255)
				Gfx.rectangle("line", x * 32, y * 32, 32,32)
			end
		end
	end
end

-- Tile interface

function M.render(tile, gx, gy)
	local id = tile
	local prop = Asset.tileset.prop[id]
	assert(prop)
	local x, y = gx * 32, gy * 32
	Gfx.setColor(255,255,255, 255)
	Gfx.draw(
		Asset.atlas.tileset.tex,
		prop.quad,
		x - prop.width / 2 + 16,
		y - prop.height + 32
	)
end

return M
