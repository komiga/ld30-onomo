
require("src/Util")
require("src/AudioManager")
require("src/Animator")

local M = def_module("AssetLoader", nil)

local Kind = {}

local function get_asset_path(root_path, path, name, ext)
	type_assert(path, "string", true)
	local p_ext = (nil ~= ext) and ('.' .. ext) or ""
	if nil == path then
		return root_path .. name .. p_ext
	else
		return root_path .. string.gsub(path, '@', name) .. p_ext
	end
end

--[[

NOTE: '@' in descriptor paths will be replaced with the name of the asset.

All descriptors can take a 'path' value, but default to 'name.ext'
where 'ext' is the default extension for the asset kind. 'ext' can be
used to override the default extension.

All assets except for fonts (that is, all tables) will have a unique
integer value '__id' and '__name' set to the asset's name.

]]

--[[

With path (using name and .ttf):

	name = {
		18
	}

Or default font with size:

	name = {
		18,
		default = true
	}

]]
Kind.font = {
	slug = "font/",
	loader = function(root_path, name, desc)
		local size = desc[1]
		local default = desc.default
		type_assert(size, "number")
		type_assert(default, "boolean", true)

		if default then
			return Gfx.newFont(size)
		else
			return Gfx.newFont(
				get_asset_path(root_path, desc.path, name, desc.ext or "ttf"),
				size
			)
		end
	end
}

--[[

With positions and sizes:

	name = {
		tex = {
			{"t0",  0,0, 32,32},
			{"t1", 32,0, 32,32},
			{"t2", 64,0, 32,32}
		}
	}

With constant size:

	name = {
		size = {32,32},
		tex = {
			{"t0",  0,0},
			{"t1", 32,0},
			{"t2", 64,0}
		}
	}

With constant size and indexed positions:

	name = {
		indexed = true,
		size = {32,32},
		tex = {
			{"t0", 0,0},
			{"t1", 1,0},
			{"t2", 2,0}
		}
	}

All of the descriptors above describe the same atlas.

In the last two forms, full quads are still permitted
(in which form the position for the texture does not use indexing).

]]
Kind.atlas = {
	slug = "atlas/",
	loader = function(root_path, name, desc)
		local indexed = desc.indexed
		local size = desc.size
		local tex = desc.tex
		type_assert(indexed, "boolean", true)
		type_assert(size, "table", true)
		type_assert(tex, "table")

		local atlas = {
			tex = Gfx.newImage(
				get_asset_path(root_path, desc.path, name, desc.ext or "png")
			)
		}

		local aw = atlas.tex:getWidth()
		local ah = atlas.tex:getHeight()
		local x0,y0, sw,sh
		local idx, t

		if indexed and not size then
			error("indexed positions require a size")
		end

		for idx, t in pairs(tex) do
			if 3 ~= #t and 5 ~= #t then
				error(
					"atlas subtexture descriptor " .. 
					idx .. " is malformed"
				)
			end
			if 5 ~= #t and not size then
				error(
					"atlas subtextures must be full " .. 
					"quads if 'size' is absent."
				)
			end
			x0 = t[2]
			y0 = t[3]
			if indexed then
				x0 = size[1] * x0
				y0 = size[2] * y0
			end
			if 5 == #t then
				sw = t[4]
				sh = t[5]
			else
				sw = size[1]
				sh = size[2]
			end
			atlas[t[1]] = Gfx.newQuad(x0,y0, sw,sh, aw,ah)
		end
		return atlas
	end
}

--[[

Animation data.

	name = {
		duration = 0.2,
		size = {32,32},
		set = {
			{10},
			{10},
			{10}
		}
	}

'duration' is the duration of a frame (in seconds).

'size' is the size of each frame.

'set' defines sequence sets. Each set contains only a frame count.

A set will automatically move to the next row if the end of a row is
reached before all of its frames are loaded.

If a set is completed and the frame isn't the last frame in the row,
the next row will be used for the next set. This can be disabled with
tight_packing = true.

Once loaded, a frame quad is accessed by index:

	anim_data.set[set][frame]

Each frame is a Quad.

See Animator.Instance.

]]
Kind.anim = {
	slug = "anim/",
	loader = function(root_path, name, desc)
		local duration = desc.duration
		local size = desc.size
		local set = desc.set
		local tight_packing = desc.tight_packing
		type_assert(duration, "number")
		type_assert(size, "table")
		type_assert(set, "table")
		type_assert(tight_packing, "boolean", true)

		local ad = {
			duration = duration,
			frame_width = size[1],
			frame_height = size[2],
			set = {},
			tex = Gfx.newImage(
				get_asset_path(root_path, desc.path, name, desc.ext or "png")
			)
		}
		ad.tex_width = ad.tex:getWidth()
		ad.tex_height = ad.tex:getHeight()

		local dw = ad.frame_width
		local dh = ad.frame_height
		local x0, y0 = 0, 0

		assert(dw <= ad.tex_width)
		assert(dh <= ad.tex_height)

		local y0_overflow = function(sidx)
			error("animation set " .. sidx .. " overflows texture")
		end

		for sidx, s in pairs(set) do
			ad.set[sidx] = {}
			x0 = 0
			for frame = 1, s[1] do
				if ad.tex_width < x0 + dw then
					x0 = 0
					y0 = y0 + dh
					if ad.tex_height < y0 then
						y0_overflow(sidx)
					end
				end
				ad.set[sidx][frame] = Gfx.newQuad(
					x0,y0, dw,dh, ad.tex_width,ad.tex_height
				)
				x0 = x0 + dw
			end
			if not tight_packing then
				y0 = y0 + dh
				if ad.tex_height < y0 then
					y0_overflow(sidx)
				end
			end
		end
		return ad
	end
}

--[[

With path, instance policy, and instance limit:

	name = {
		InstancePolicy.Constant,
		limit = 10
	}

'limit' is 0 by default.

The second parameter is the instance policy. This is defaulted to
Constant if limit > 0, or Immediate if limit <= 0.

See AudioManager.SoundInstance.

--]]
Kind.sound = {
	slug = "sound/",
	loader = function(root_path, name, desc)
		local policy = desc[1]
		local limit = desc.limit
		type_assert(policy, "number", true)
		type_assert(limit, "number", true)

		limit = optional(limit, 0)
		policy = optional(
			policy,
			ternary(
				0 < limit,
				AudioManager.InstancePolicy.Constant,
				AudioManager.InstancePolicy.Immediate
			)
		)
		if AudioManager.InstancePolicy.Constant == policy and 0 == limit then
			error("policy cannot be Constant when limit=0")
		end

		local sd = {
			data = love.sound.newSoundData(
				get_asset_path(root_path, desc.path, name, desc.ext or "ogg")
			),
			policy = policy,
			limit = limit
		}
		return sd
	end
}

Kind.music = {
	slug = "music/",
	loader = function(root_path, name, desc)
		type_assert(desc.loop, "boolean", true)
		type_assert(desc.volume, "number", true)
		local asset = {
			source = Sfx.newSource(
				get_asset_path(root_path, desc.path, name, desc.ext or "ogg")
			),
			loop = optional(desc.loop, true),
			volume = optional(desc.volume, 1.0),
		}
		asset.source:setLooping(asset.loop)
		asset.source:setVolume(asset.volume)
		return asset
	end
}

Kind.entity = {
	slug = "entity/",
	loader = function(root_path, name, desc)
		type_assert(desc.controlled, "boolean", true)
		type_assert(desc.blend_mode, "string", true)
		type_assert(desc.height, "number")
		type_assert(desc.light, "table", true)

		desc.controlled = optional(desc.controlled, false)
		desc.blend_mode = optional(desc.blend_mode, "alpha")
		if desc.light then
			type_assert(desc.light.kind, "string", true)
			type_assert(desc.light.blend_mode, "string", true)
			type_assert(desc.light.sx, "number")
			type_assert(desc.light.sy, "number")
			type_assert(desc.light.inner_power, "number", true)
			type_assert(desc.light.inner_height_add, "number", true)
			desc.light.kind = optional(desc.light.kind, "glow")
			desc.light.blend_mode = optional(desc.light.blend_mode, "alpha")
			desc.light.inner_power = optional(desc.light.inner_power, 60)
			desc.light.inner_height_add = optional(desc.light.inner_height_add, 0)
			assert(Asset.atlas.light[desc.light.kind])
		end

		type_assert(desc.static, "table", true)
		if desc.static then
			type_assert(desc.anim_data, "nil")
			type_assert(desc.anim, "nil")
			type_assert(desc.static.atlas, "string")
			type_assert(desc.static.sidx, "string")
			local atlas = Asset.atlas[desc.static.atlas]
			assert(atlas)
			assert(atlas[desc.static.sidx])
		else
			type_assert(desc.anim_name, "string")
			type_assert(desc.anim, "table")

			local anim_data = Asset.anim[desc.anim_name]
			assert(anim_data)
			for _, prop in pairs(desc.anim) do
				type_assert(prop.index, "number")
				type_assert(prop.mode, "number")
				type_assert(prop.passive, "boolean", true)
				prop.passive = optional(prop.passive, false)
				assert(1 <= prop.index and #anim_data.set >= prop.index)
			end
			desc.anim_data = anim_data
		end

		type_assert(desc.rune, "table", true)
		if desc.rune then
			type_assert(desc.rune.sound_name, "string")
			type_assert(desc.rune.corune, "string")
			assert(Asset.sound[desc.rune.sound_name])
		end
		return desc
	end
}

Kind.tileset = {
	slug = "tileset/",
	preload = function(root_path, desc_table, asset_kind_table)
		local layer_for_name = {
			bg = World.LayerID.bg,
			fg = World.LayerID.fg,
			og = World.LayerID.og,
		}
		local count = 0
		assert(desc_table.ranges)
		asset_kind_table.prop = {}
		for range_name, range in pairs(desc_table.ranges) do
			assert(layer_for_name[range_name])
			for _, subtex in pairs(Asset.desc_root.atlas.tileset.tex) do
				local sidx = subtex[1]
				if sidx >= range[1] and sidx <= range[2] then
					local quad = Asset.atlas.tileset[sidx]
					local _,_, w,h = quad:getViewport()
					local prop = {
						quad = quad,
						width = w,
						height = h,
						layer = layer_for_name[range_name],
					}
					table.insert(asset_kind_table.prop, sidx, prop)
					count = count + 1
				end
			end
		end
		asset_kind_table.count = count
	end
}

local LoadOrder = {
	"font",
	"atlas",
	"anim",
	"sound",
	"music",
	"entity",
	"tileset",
}

local function load_kind(id, root_path, kind_name, desc_table, asset_table)
	local kind = Kind[kind_name]
	root_path = root_path .. kind.slug
	local asset_kind_table = asset_table[kind_name]
	if kind.preload then
		kind.preload(root_path, desc_table, asset_kind_table)
	end
	if kind.loader then
		for name, desc in pairs(desc_table) do
			type_assert(desc, "table")
			local asset = kind.loader(root_path, name, desc)
			assert(nil ~= asset)
			if "table" == type(asset) then
				asset.__id = id
				asset.__name = tostring(name)
				id = id + 1
			end
			asset_kind_table[name] = asset
		end
	end
	return id
end

function M.load(root_path, desc_root, asset_table)
	type_assert(root_path, "string")
	type_assert(desc_root, "table")
	type_assert(asset_table, "table")

	local id = 1
	for _, kind_name in pairs(LoadOrder) do
		local desc_table = desc_root[kind_name]
		if nil ~= desc_table then
			if nil == asset_table[kind_name] then
				asset_table[kind_name] = {}
			end
			id = load_kind(id, root_path, kind_name, desc_table, asset_table)
		end
	end
end

return M
