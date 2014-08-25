
require("src/State")

--local M_lrandom = require("random")

Util = Util or {}
local M = Util

--[[M.data = M.data or {
	rng = nil
}--]]

function M.init()
	--M.data.rng = M_lrandom.new(os.time())
	math.randomseed(os.time())
end

function ternary(cond, x, y)
	return (cond)
		and x
		or  y
end

function optional(value, default)
	return (nil ~= value)
		and value
		or default
end

function is_type(x, tc)
	return
		type(tc) == "table"
		and (type(x) == "table" and tc == x.__index)
		or  tc == type(x)
end

function type_assert(x, tc, opt)
	opt = optional(opt, false)
	assert(
		(opt and nil == x)
		or is_type(x, tc),
		"type_assert: '" .. tostring(x) .. "' (a " .. type(x) .. ") is not of type " .. tostring(tc)
	)
end

function type_assert_obj(x, tc, opt)
	opt = optional(opt, false)
	assert(
		(opt and nil == x)
		or x:typeOf(tc)
	)
end

function table.last(t)
	assert(0 < #t)
	return t[#t]
end

function table.at_index(t, index)
	for i, v in ipairs(t) do
		if i == index then
			return v
		end
	end
	return nil
end

function table.index_of(t, value)
	for i, v in ipairs(t) do
		if v == value then
			return i
		end
	end
	return nil
end

local function get_trace()
	local info = debug.getinfo(3, "Sl")
	local function pad(str, length)
		if #str < length then
			while #str < length do
				str = ' ' .. str
			end
		end
		return str
	end
	return info.short_src .. " @ " .. pad(tostring(info.currentline), 4)
end

function trace()
	print(get_trace() .. ": TRACE")
end

function log(msg, ...)
	type_assert(msg, "string")
	print(get_trace() .. ": " .. string.format(msg, ...))
end

function log_debug_sys(sys, msg, ...)
	type_assert(msg, "string")
	if true == sys then
		print(get_trace() .. ": debug: " .. string.format(msg, ...))
	end
end

function log_debug(msg, ...)
	type_assert(msg, "string")
	if true == State.gen_debug then
		print(get_trace() .. ": debug: " .. string.format(msg, ...))
	end
end

function random(x, y)
	--return M.data.rng:value(x, y)
	return math.random(x, y)
end

function choose_random(table)
	return table[random(1, #table)]
end

function set_functable(t, func)
	if not t.__class_static then
		t.__class_static = {}
		t.__class_static.__index = t.__class_static
		setmetatable(t, t.__class_static)
	end
	t.__class_static.__call = func
end

function class(c)
	if nil == c then
		c = {}
		c.__index = c
		set_functable(c, function(c, ...)
			local obj = {}
			setmetatable(obj, c)
			obj:__init(...)
			return obj
		end)
	end
	return c
end

function def_module(name, data)
	type_assert(name, "string")
	type_assert(data, "table", true)

	local m = _G[name] or {}
	if not m.data and data then
		m.data = data
	end
	_G[name] = m
	return m
end

function def_module_unit(name, data)
	local m = def_module(name, data)
	set_functable(m, function(m, ...)
		local obj = {}
		setmetatable(obj, m.Unit)
		obj:__init(...)
		return obj
	end)
	return m
end

function min(x, y)
	return x < y and x or y
end

function max(x, y)
	return x > y and x or y
end

function clamp(x, min, max)
	return x < min and min or x > max and max or x
end

-- takes:
--	(rgba, alpha_opt),
--	(rgb, alpha), or
--	(rgb) with alpha = 255
function set_color_table(rgb, alpha)
	alpha = optional(
		alpha,
		optional(rgb[4], 255)
	)
	Gfx.setColor(rgb[1],rgb[2],rgb[3], alpha)
end

return M
