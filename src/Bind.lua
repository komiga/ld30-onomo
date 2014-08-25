
require("src/Util")

local M = def_module("Bind", {
	__initialized = false,

	global_group = nil,
	gate_fn = nil,
	stack = nil,
	active = nil,
	modifiers = nil,
	mouse_enabled = nil
})

M.Kind = {
	Press = 1,
	Active = 2,
	Release = 3
}

local MouseButton = {
	love = {
		["l"] = "mouse1",
		["r"] = "mouse2",
		["m"] = "mouse3",
		["wu"] = "mwheelup",
		["wd"] = "mwheeldown"
	},
	native = {
		["mouse1"] = "l",
		["mouse2"] = "r",
		["mouse3"] = "m",
		["mwheelup"] = "wu",
		["mwheeldown"] = "wd"
	}
}

local BadGateKeys = {
	["numlock"] = true,
	["capslock"] = true,
	["scrollock"] = true,
	["rshift"] = true,
	["lshift"] = true,
	["rctrl"] = true,
	["lctrl"] = true,
	["ralt"] = true,
	["lalt"] = true,
	["rmeta"] = true,
	["lmeta"] = true,
	["lsuper"] = true,
	["rsuper"] = true,
	["mode"] = true,
	["compose"] = true
}

local Modifier = {
	["rshift"] = true,
	["lshift"] = true,
	["rctrl"] = true,
	["lctrl"] = true,
	["ralt"] = true,
	["lalt"] = true,
	["rmeta"] = true,
	["lmeta"] = true,
	["lsuper"] = true,
	["rsuper"] = true,
}

-- internal

local function make_bind(check, ident, bind, table)
	if true == check[ident] then
		error("multiple bind to ident '" .. ident .. "'")
	end
	table[ident] = bind
	check[ident] = true
end

local function exec_gate(bind, ident, dt, kind)
	local bad = BadGateKeys[ident]
	if not bad then
		return M.data.gate_fn(bind, ident, dt, kind)
	end
	return false
end

local function trigger(bind, ident, dt, kind)
	if
		true == bind.system or
		true == exec_gate(bind, ident, dt, kind) or
		true == bind.passthrough
	then
		if nil ~= bind.handler then
			bind.handler(ident, dt, kind, bind)
		end
	end
end

local function bind_press(ident, _)
	if Modifier[ident] then
		M.data.modifiers[ident] = true
	end
	local bind = Bind.get_bind(ident)
	if nil ~= bind then
		if bind.on_press then
			trigger(bind, ident, 0.0, Bind.Kind.Press)
		else
			exec_gate(bind, ident, 0.0, Bind.Kind.Press)
		end
		if bind.on_active and exec_gate(bind, ident, 0.0, Bind.Kind.Active) then
			M.data.active[ident] = bind
		end
	else
		exec_gate(nil, ident, 0.0, Bind.Kind.Press)
	end
end

local function bind_release(ident)
	if Modifier[ident] then
		M.data.modifiers[ident] = false
	end
	local bind = Bind.get_bind(ident)
	if nil ~= bind then
		if bind.on_active and exec_gate(bind, ident, 0.0, Bind.Kind.Active) then
			M.data.active[ident] = nil
		end
		if bind.on_release then
			trigger(bind, ident, 0.0, Bind.Kind.Release)
		else
			exec_gate(bind, ident, 0.0, Bind.Kind.Release)
		end
	else
		exec_gate(nil, ident, 0.0, Bind.Kind.Release)
	end
end

-- class Group

M.Group = class(M.Group)

function M.Group:__init(bind_table)
	type_assert(bind_table, "table")

	self.bind_table_source = bind_table
	self.bind_table = {}
	self:add(bind_table)
end

function M.Group:has_ident(ident)
	return nil ~= self.bind_table[ident]
end

function M.Group:get_bind(ident)
	return self.bind_table[ident]
end

function M.Group:add(bind_table)
	type_assert(bind_table, "table")

	local check = {}
	local expanded = {}
	for ident, bind in pairs(bind_table) do
		type_assert(bind, "table")
		bind.ident = ident
		if "table" == type(ident) then
			for _, sub_ident in pairs(ident) do
				make_bind(check, sub_ident, bind, expanded)
			end
		else
			make_bind(check, ident, bind, expanded)
		end
	end
	for ident, bind in pairs(expanded) do
		self.bind_table[ident] = bind
	end
end

function M.Group:replace(replacement)
	self:__init(replacement)
end

-- Bind interface

function M.init(global_group, gate_fn, enable_mouse)
	type_assert(global_group, "table")
	type_assert(gate_fn, "function")
	type_assert(enable_mouse, "boolean", true)

	assert(not M.data.__initialized)

	M.data.global_group = Bind.Group(global_group)
	M.data.gate_fn = gate_fn
	M.data.stack = {}
	M.data.active = {}
	M.data.modifiers = {}
	M.data.mouse_enabled = optional(enable_mouse, true)

	M.data.__initialized = true
end

function M.count()
	return #M.data.stack
end

function M.set_gate(gate_fn)
	M.data.gate_fn = gate_fn
end

function M.push_group(group)
	type_assert(group, Bind.Group)

	table.insert(M.data.stack, group)
end

function M.pop_group(group)
	assert(0 < Bind.count())
	type_assert(group, Bind.Group)

	assert(group == M.data.stack[Bind.count()])
	table.remove(M.data.stack)
end

function M.active_group()
	return ternary(
		0 < Bind.count(),
		M.data.stack[Bind.count()],
		M.data.global_group
	)
end

function M.replace_group(bind_table, replacement)
	type_assert(bind_table, "table")
	type_assert(replacement, "table")

	for _, group in ipairs(M.data.stack) do
		if group.bind_table_source == bind_table then
			group:replace(replacement)
			return
		end
	end
	assert(false, "group not found for bind table")
end

function M.redefine_group(bind_table, replacement)
	if bind_table then
		M.replace_group(bind_table, replacement)
	end
	return replacement
end

function M.is_active(native)
	return M.data.active[native]
end

function M.has_modifiers(...)
	for _, native in ipairs({...}) do
		if not M.data.modifiers[native] then
			return false
		end
	end
	return 0 < #...
end

function M.has_modifiers_any(...)
	for _, native in ipairs({...}) do
		if M.data.modifiers[native] then
			return true
		end
	end
	return false
end

function M.get_bind(ident)
	local bind = nil
	for idx = Bind.count(), 1, -1 do
		bind = M.data.stack[idx]:get_bind(ident)
		if nil ~= bind then
			break
		end
	end
	return bind or M.data.global_group:get_bind(ident)
end

function M.mouse_press(_, _, button)
	local native = MouseButton.love[button]
	if nil ~= native then
		bind_press(native)
	end
end

function M.mouse_release(_, _, button)
	local native = MouseButton.love[button]
	if nil ~= native then
		bind_release(native)
	end
end

function M.update(dt)
	for ident, bind in pairs(M.data.active) do
		trigger(bind, ident, dt, Bind.Kind.Active)
	end
end

function M.clear_active()
	M.data.active = {}
end

-- LÖVE sinks
function love.keypressed(key, _)
	bind_press(key, _)
end

function love.keyreleased(key)
	bind_release(key, nil)
end

-- NB: For some reason disabling the mouse module does not disable
-- mouse events..
function love.mousepressed(x, y, button)
	if M.data.mouse_enabled then
		Bind.mouse_press(x, y, button)
	end
end

function love.mousereleased(x, y, button)
	if M.data.mouse_enabled then
		Bind.mouse_release(x, y, button)
	end
end

return M
