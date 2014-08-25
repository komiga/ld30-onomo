
require("src/Util")

local M = def_module("Animator", {
	__initialized = false
})

M.Mode = {
	Stop = 1,
	Loop = 2,
	Bounce = 3
}

M.BatchMode = {
	Dynamic = 1,
	Static = 2,
	Stream = 3
}

local BatchModeName = {
	"dynamic",
	"static",
	"stream"
}

-- class Instance

M.Instance = class(M.Instance)

function M.Instance:__init(anim_data, anim_index, mode)
	type_assert(anim_data, "table")
	type_assert(anim_index, "number")
	type_assert(mode, "number", true)

	mode = optional(mode, M.Mode.Stop)

	self.batch_id = nil
	self.data = anim_data
	self.x, self.y = 0, 0
	self.r = nil
	self.sx, self.sy = nil, nil
	self.ox, self.oy = nil, nil
	self:reset(anim_index, mode)
end

function M.Instance:reset(anim_index, mode)
	type_assert(anim_index, "number")
	type_assert(mode, "number", true)
	assert(1 <= anim_index and #self.data.set >= anim_index)

	self.mode = optional(mode or self.mode)
	self.playing = true
	self.set = self.data.set[anim_index]
	self.frame_count = #self.set
	self.accum = 0.0
	self.frame = 1
	self.reverse = false
end

function M.Instance.rewind(frame)
	if nil ~= frame then
		self.accum = frame * self.data.duration
		self.frame = frame
	else
		self.accum = 0.0
		self.frame = 1
	end
	self.playing = true
end

function M.Instance:is_playing()
	return self.playing
end

-- Will return false if either the animation is
-- not playing or if the animation has looped
function M.Instance:update(dt, batcher)
	if not self.playing then
		return
	end
	self.accum = self.accum + dt
	if self.data.duration <= self.accum then
		local amt = math.floor(self.accum / self.data.duration)
		local new_frame = self.frame + (self.reverse and -amt or amt)
		if 1 > new_frame or self.frame_count < new_frame then
			if M.Mode.Bounce == self.mode then
				self.accum = 0.0
				self.frame = self.reverse and 1 or self.frame_count
				self.reverse = not self.reverse
			elseif M.Mode.Loop == self.mode then
				self.accum = 0.0
				self.frame = 1
			else
				self.frame = self.frame_count
				self.playing = false
			end
		else
			self.accum = self.accum - (amt * self.data.duration)
			self.frame = new_frame
		end
		if batcher then
			batcher:set(self)
		end
	end
end

function M.Instance:render()
	Gfx.draw(
		self.data.tex,
		self.set[self.frame],
		self.x,self.y, self.r, self.sx,self.sy, self.ox,self.oy
	)
end

-- class Batcher

M.Batcher = class(M.Batcher)

function M.Batcher:__init(anim_data, limit, mode)
	type_assert(anim_data, "table")
	type_assert(limit, "number")
	type_assert(mode, "number", true)

	mode = optional(mode, Animator.BatchMode.Dynamic)

	self.data = anim_data
	self.limit = limit
	self.mode = mode
	self.batch = Gfx.newSpriteBatch(
		self.data.tex,
		self.limit,
		BatchModeName[self.mode]
	)
	self.instances = {}
end

function M.Batcher:clear()
	for _, i in ipairs(self.instances) do
		i.batch_id = nil
	end
	self.instances = {}
	self.batch:clear()
end

function M.Batcher:batch_begin()
	self.batch:bind()
end

function M.Batcher:batch_end()
	self.batch:unbind()
end

-- NOTE: Add order determines render order
function M.Batcher:add(i)
	assert(#self.instances < self.limit, "Batcher: batch full")
	assert(self.data == i.data)
	assert(not i.batch_id)
	i.batch_id = self.batch:add(
		i.set[i.frame],
		i.x,i.y, i.r, i.sx,i.sy, i.ox,i.oy
	)
	table.insert(self.instances, i)
	return #self.instances
end

function M.Batcher:set(i)
	assert(i.batch_id)
	self.batch:set(
		i.batch_id,
		i.set[i.frame],
		i.x,i.y, i.r, i.sx,i.sy, i.ox,i.oy
	)
end

function M.Batcher:update(dt)
	self:batch_begin()
	for _, i in ipairs(self.instances) do
		i:update(dt, self)
	end
	self:batch_end()
end

function M.Batcher:render(x, y, r, sx, sy, ox, oy)
	Gfx.draw(self.batch, x, y, r, sx, sy, ox, oy)
end

-- Animator interface

function M.init(anim_table)
	type_assert(anim_table, "table")
	assert(not M.data.__initialized)

	M.data.__initialized = true
end

return M
