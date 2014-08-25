
require("src/Util")

local M = def_module_unit("Timer", nil)

-- class Timer

M.Unit = class(M.Unit)

function M.Unit:__init(duration)
	self.duration = 0.0
	self:reset(duration)
end

function M.Unit:reset(new_duration)
	type_assert(new_duration, "number", true)
	self.duration = optional(new_duration, duration)
	self.elapsed = 0.0
	self.ticks = 0
end

function M.Unit:has_duration()
	return 0.0 ~= self.duration
end

function M.Unit:duration()
	return self.duration
end

function M.Unit:elapsed()
	return self.elapsed
end

function M.Unit:ticks()
	return self.ticks
end

function M.Unit:update(dt)
	self.elapsed = self.elapsed + dt
	if self:has_duration() then
		if self.elapsed > self.duration then
			self.elapsed = self.elapsed - self.duration
			self.ticks = self.ticks + 1
			return true
		end
	end
	return false
end

return M
