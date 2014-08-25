
require("src/Util")

local M = def_module_unit("FieldAnimator", nil)

FieldAnimator.Mode = {
	Stop = 1,
	Wrap = 2,
	Continue = 3
}

-- class FieldAnimator

M.Unit = class(M.Unit)

function M.Unit:__init(duration, fields, trans, mode, serial_reset_callback)
	type_assert(duration, "number")
	type_assert(fields, "table")
	type_assert(trans, "table")
	type_assert(mode, "number", true)
	type_assert(serial_reset_callback, "function", true)

	self.duration = duration
	self.fields = fields
	self.trans = trans
	self.mode = optional(mode, FieldAnimator.Mode.Stop)
	self.serial_reset_callback = serial_reset_callback
	self:reset()
end

function M.Unit:is_complete()
	return 1.0 <= self.total
end

function M.Unit:reset(new_duration)
	type_assert(new_duration, "number", true)
	self.duration = optional(new_duration, self.duration)
	self.time = 0.0
	self.total = 0.0
	self.picked = {}
	for f, t in pairs(self.trans) do
		if "table" == type(t[1]) then
			-- trans for field is a table of variants
			-- instead of a direct (base,target) pair
			local index = random(1, #t)
			self.picked[f] = index
		end
		local value = self:get_field_trans(f)[1]
		if "table" == type(f) then
			for _, af in pairs(f) do
				self:__post(af, value)
			end
		else
			self:__post(f, value)
		end
	end
end

function M.Unit:get_field_trans(f)
	local index = self.picked[f]
	if nil ~= index then
		return self.trans[f][index]
	else
		return self.trans[f]
	end
end

function M.Unit:__post(f, value)
	if "function" == type(self.fields[f]) then
		self.fields[f](value, self)
	else
		self.fields[f] = value
	end
end

function M.Unit:__update_field_table(f, t)
	local value = t[1] + ((t[2] - t[1]) * self.total)
	for _, af in pairs(f) do
		self:__post(af, value)
	end
end

function M.Unit:__update_field(f, t)
	local value = t[1] + ((t[2] - t[1]) * self.total)
	self:__post(f, value)
end

function M.Unit:update(dt)
	self.time = self.time + dt
	if FieldAnimator.Mode.Continue ~= self.mode and self.time >= self.duration then
		if FieldAnimator.Mode.Stop == self.mode then
			self.time = self.duration
			self.total = 1.0
			if self.serial_reset_callback then
				self.serial_reset_callback(self)
			end
		elseif FieldAnimator.Mode.Wrap == self.mode then
			self:reset()
			if self.serial_reset_callback then
				self.serial_reset_callback(self)
			end
		end
	else
		self.total = self.time / self.duration
	end
	for f, _ in pairs(self.trans) do
		if "table" == type(f) then
			self:__update_field_table(f, self:get_field_trans(f))
		else
			self:__update_field(f, self:get_field_trans(f))
		end
	end
	return self:is_complete()
end

return M
