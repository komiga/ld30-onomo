
require("src/Util")
require("src/Bind")

local M = def_module_unit("Scene", {
	__initialized = false,
	stack = nil
})

-- class Scene

M.Unit = class(M.Unit)

function M.Unit:__init(impl, bind_group, transparent)
	type_assert(impl, "table")
	type_assert(impl.notify_pushed, "function", true)
	type_assert(impl.notify_popped, "function", true)
	type_assert(impl.update, "function")
	type_assert(impl.render, "function")
	type_assert(impl.bind_gate, "function", true)
	type_assert(impl.on_pause_changed, "function", true)
	type_assert(bind_group, Bind.Group, true)
	type_assert(transparent, "boolean", true)

	self.impl = impl
	self.impl.scene_unit = self
	self.bind_group = bind_group
	self.transparent = optional(transparent, false)
end

function M.Unit:is_transparent()
	return self.transparent
end

function M.Unit:is_top()
	return Scene.current() == self
end

function M.Unit:notify_pushed()
	if nil ~= self.bind_group then
		Bind.push_group(self.bind_group)
	end
	if nil ~= self.impl.notify_pushed then
		self.impl:notify_pushed()
	end
end

function M.Unit:notify_became_top()
	if nil ~= self.impl.notify_became_top then
		self.impl:notify_became_top()
	end
end

function M.Unit:notify_popped()
	if nil ~= self.bind_group then
		Bind.pop_group(self.bind_group)
	end
	if nil ~= self.impl.notify_popped then
		self.impl:notify_popped()
	end
end

function M.Unit:bind_gate(bind, ident, dt, kind)
	if nil ~= self.impl.bind_gate then
		return self.impl:bind_gate(bind, ident, dt, kind)
	end
	return true
end

function M.Unit:on_pause_changed(new_paused)
	if nil ~= self.impl.on_pause_changed then
		return self.impl:on_pause_changed(new_paused)
	end
	return true
end

function M.Unit:update(dt)
	self.impl:update(dt)
end

function M.Unit:render()
	self.impl:render()
end

-- Scene interface

function M.init()
	assert(not M.data.__initialized)
	M.data.stack = {}
	M.data.__initialized = true
end

function M.count()
	return #M.data.stack
end

function M.current()
	return 0 < M.count() and M.data.stack[M.count()] or nil
end

function M.push(scene)
	type_assert(scene, Scene.Unit)

	table.insert(M.data.stack, scene)
	scene:notify_pushed()
end

function M.pop(scene)
	type_assert(scene, Scene.Unit)

	if 0 == M.count() then
		log_debug("Scene.pop(): attempted to pop on empty stack")
	end
	assert(nil ~= scene and scene == M.current())

	table.remove(M.data.stack)
	scene:notify_popped()

	scene = M.current()
	if nil ~= scene then
		scene:notify_became_top()
	end
end

function M.clear()
	while 0 ~= M.count() do
		M.pop(M.current())
	end
end

function M.bind_gate(bind, ident, dt, kind)
	local scene = M.current()
	if nil ~= scene then
		return scene:bind_gate(bind, ident, dt, kind)
	end
	return true
end

function M.on_pause_changed(new_paused)
	local scene = M.current()
	if nil ~= scene then
		return scene:on_pause_changed(new_paused)
	end
	return true
end

function M.update(dt)
	local scene = M.current()
	if nil ~= scene then
		if scene:is_transparent() and 1 < M.count() then
			M.data.stack[M.count() - 1]:update(dt)
		end
		scene:update(dt)
	end
end

function M.render()
	local scene = M.current()
	if nil ~= scene then
		if scene:is_transparent() and 1 < M.count() then
			M.data.stack[M.count() - 1]:render()
		end
		scene:render()
	end
end

return M
