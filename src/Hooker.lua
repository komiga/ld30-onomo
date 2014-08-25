
require("src/Util")
require("src/FieldAnimator")

local M = def_module("Hooker", {
	__initialized = false,
	active = nil
})

-- class Hooklet

M.Hooklet = class(M.Hooklet)

function M.Hooklet:__init(props, x, y)
	type_assert(props, "table")
	type_assert(x, "number")
	type_assert(y, "number")

	self.props = props
	self.x = x
	self.y = y
	self.fields = {}
	self.animator = FieldAnimator(
		self.props.duration,
		self.fields,
		self.props.trans,
		FieldAnimator.Mode.Stop
	)
end

function M.Hooklet:update(dt)
	if self.animator:is_complete() then
		return false
	else
		self.animator:update(dt)
		return true
	end
end

function M.Hooklet:render()
	set_color_table(self.props.color, self.fields.alpha)
	Gfx.setFont(self.props.font)
	Gfx.print(
		self.props.text,
		self.x + self.fields.tx,
		self.y + self.fields.ty,
		self.fields.angle,
		self.fields.sx, self.fields.sy,
		self.props.half_width, self.props.half_height
	)
end

-- Hooker interface

function M.init(hooklet_props, default_font)
	type_assert(hooklet_props, "table")
	type_assert_obj(default_font, "Font", true)
	assert(not M.data.__initialized)

	if nil == default_font then
		default_font = Gfx.getFont()
		assert(nil ~= default_font)
	end

	for _, props in pairs(hooklet_props) do
		if nil == props.font then
			props.font = default_font
		end
		props.half_width = 0.5 * props.font:getWidth(props.text)
		props.half_height = 0.5 * props.font:getHeight()
		if nil == props.trans["alpha"] then
			props.trans["alpha"] = {255.0, 0.0}
		end
	end

	M.data.active = {}
	M.data.__initialized = true
end

function M.num_active()
	return #M.data.active
end

function M.clear()
	M.data.active = {}
end

function M.clear_specific(props)
	local rmkeys = {}
	for idx, hkl in ipairs(M.data.active) do
		if hkl.props == props then
			table.insert(rmkeys, 1, idx)
		end
	end
	if 0 < #rmkeys then
		for _, idx in pairs(rmkeys) do
			table.remove(M.data.active, idx)
		end
	end
end

function M.spawn(props, x, y)
	local hkl = M.Hooklet(props, x, y)
	table.insert(M.data.active, hkl)
end

function M.update(dt)
	local rmkeys = {}
	for idx, hooklet in pairs(M.data.active) do
		if not hooklet:update(dt) then
			table.insert(rmkeys, 1, idx)
		end
	end
	if 0 < #rmkeys then
		for _, idx in pairs(rmkeys) do
			table.remove(M.data.active, idx)
		end
	end
end

function M.render()
	for _, hooklet in pairs(M.data.active) do
		Gfx.push()
		hooklet:render()
		Gfx.pop()
	end
end

return M
