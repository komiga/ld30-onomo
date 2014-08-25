
require("src/Util")

local M = def_module("AudioManager", {
	__initialized = false,
	paused = nil,
	buckets = nil
})

M.InstancePolicy = {
	-- Kill immediately, regardless of limit; grow past limit
	Immediate = 1,
	-- Never kill, never grow
	Constant = 2,
	-- Can grow past limit, does not go below limit
	Reserve = 3,
	-- Never kill, never grow; trample active sounds
	Trample = 4
}

-- class SoundInstance

M.SoundInstance = class(M.SoundInstance)

function M.SoundInstance:__init(sound_data, x, y, z)
	self.source = Sfx.newSource(sound_data.data, "static")
	self:set_position(x, y, z)
end

function M.SoundInstance:set_position(x, y, z)
	self.source:setPosition(x, y, z)
end

function M.SoundInstance:stop()
	self.source:stop()
end

function M.SoundInstance:play()
	self.source:play()
end

function M.SoundInstance:restart()
	self.source:rewind()
end

function M.SoundInstance:is_playing()
	return not self.source:isStopped()
end

function M.SoundInstance:update(_)
	return self:is_playing()
end

-- class Bucket

M.Bucket = class(M.Bucket)

function M.Bucket:__init(sound_data)
	type_assert(sound_data, "table")
	type_assert_obj(sound_data.data, "SoundData")

	self.data = sound_data
	self.active = {}
	self.free = {}

	if M.InstancePolicy.Immediate ~= self.data.policy then
		for i = 1, self.data.limit do
			table.insert(
				self.free,
				M.SoundInstance(sound_data, 0.0, 0.0, 0.0)
			)
		end
		self.count = self.data.limit
	end
end

function M.Bucket:can_grow()
	return
		M.InstancePolicy.Constant ~= self.data.policy and
		M.InstancePolicy.Trample ~= self.data.policy
end

function M.Bucket:spawn(x, y, z)
	local inst
	if 0 < #self.free then
		inst = table.last(self.free)
		table.remove(self.free)
	else
		if self:can_grow() then
			inst = M.SoundInstance(self.data, x, y, z)
			self.count = self.count + 1
		elseif
			M.InstancePolicy.Trample == self.policy
			and 0 < #self.active
		then
			self.active[1]:rewind()
		end
	end
	if nil ~= inst then
		table.insert(self.active, inst)
		log_debug_sys(State.sfx_debug,
			"sound spawned: " .. self.data.__name .. ": " .. #self.active
		)
		inst:play()
	end
end

function M.Bucket:update(dt)
	local policy = self.data.policy
	if 0 < #self.active then
		for i, inst in pairs(self.active) do
			if not inst:update(dt) then
				log_debug_sys(State.sfx_debug,
					"sound ended: " .. self.data.__name .. ": " .. i
				)
				table.remove(self.active, i)
				if
					M.InstancePolicy.Constant == policy
					or M.InstancePolicy.Trample == policy
					or (M.InstancePolicy.Reserve == policy
						and self.count <= self.data.limit)
				then
					log_debug_sys(State.sfx_debug, "  (kept)")
					table.insert(self.free, inst)
				else
					log_debug_sys(State.sfx_debug, "  (murdered)")
					self.count = self.count - 1
				end
			end
		end
	end
end

-- AudioManager interface

function M.init(sound_table)
	type_assert(sound_table, "table")
	assert(not M.data.__initialized)

	M.data.paused = false
	M.data.buckets = {}
	M.data.__initialized = true

	for _, sd in pairs(sound_table) do
		M.data.buckets[sd.__id] = M.Bucket(sd)
	end
end

function M.set_position(x, y, z)
	Sfx.setPosition(x, y, optional(z, 0.0))
	--log_debug("AudioManager.set_position: ", x, y, z)
end

function M.spawn(sound_data, x, y, z)
	assert(sound_data)
	local bkt = M.data.buckets[sound_data.__id]
	assert(nil ~= bkt)

	bkt:spawn(
		optional(x, 0.0),
		optional(y, 0.0),
		optional(z, 0.0)
	)
end

function M.get_bucket(sound_data)
	assert(sound_data)
	return M.data.buckets[sound_data.__id]
end

function M.pause()
	if not M.data.paused then
		Sfx.pause()
		M.data.paused = true
	end
end

function M.resume()
	if M.data.paused then
		Sfx.resume()
		M.data.paused = false
	end
end

function M.update(dt)
	if not M.data.paused then
		for _, bkt in pairs(M.data.buckets) do
			bkt:update(dt)
		end
	end
end

return M
