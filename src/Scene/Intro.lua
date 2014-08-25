
require("src/State")
require("src/Util")
require("src/Bind")
require("src/Scene")
require("src/AudioManager")
require("src/FieldAnimator")
require("src/AssetLoader")
require("src/Asset")
require("src/Timer")

local M = def_module("IntroScene", {
	trans_in = nil,
	trans_out = nil
})

M.data.trans_in = {
	["alpha"] = {{0, 255}}
}
M.data.trans_out = {
	["alpha"] = {{255, 0}}
}

-- class Impl

local Mode = {
	In = 1,
	Stay = 2,
	Out = 3
}

M.Impl = class(M.Impl)

local function make_seq(seq_data)
	assert(nil ~= seq_data)
	local seq = {}
	return seq
end

function M.Impl:__init(seq, atlas, soft)
	type_assert(seq, "table")
	type_assert(atlas, "table")
	type_assert(soft, "boolean", false)

	self.fmode_in = {}
	self.fmode_in.animator = FieldAnimator(
		0.0,
		self.fmode_in,
		M.data.trans_in,
		FieldAnimator.Mode.Stop
	)
	self.fmode_out = {}
	self.fmode_out.animator = FieldAnimator(
		0.0,
		self.fmode_out,
		M.data.trans_out,
		FieldAnimator.Mode.Stop
	)
	self.fmode_out_bg = {}
	self.fmode_out_bg.animator = FieldAnimator(
		0.0,
		self.fmode_out_bg,
		M.data.trans_out,
		FieldAnimator.Mode.Stop
	)
	self.stay_timer = Timer()

	self.sequences = seq
	self.atlas = atlas
	self.soft = soft
	self:reset()
end

function M.Impl:current_seq()
	return self.sequences[self.seq_idx]
end

function M.Impl:fmode()
	if self.mode == Mode.Stay then
		return nil
	end
	return ternary(
		self.mode == Mode.In,
		self.fmode_in,
		self.fmode_out
	)
end

function M.Impl:animator()
	if self.mode == Mode.Stay then
		return nil
	end
	return ternary(
		self.mode == Mode.In,
		self.fmode_in.animator,
		self.fmode_out.animator
	)
end

function M.Impl:is_soft()
	return self.soft
end

function M.Impl:is_last()
	return self.seq_idx == #self.sequences
end

function M.Impl:is_seq_finished()
	return self.seq_idx > #self.sequences
end

function M.Impl:is_finishing()
	return self.mode == Mode.Out and self.seq_idx >= #self.sequences
end

function M.Impl:terminate()
	log_debug("Intro:terminate()")
	Scene.pop(self.scene_unit)
end

function M.Impl:reset()
	self.mode = Mode.In
	self.seq_idx = 1
	self.fmode_in.animator:reset(self:current_seq().fade)
	self.fmode_out.animator:reset(self:current_seq().fade)
	self.fmode_out_bg.animator:reset()
end

function M.Impl:notify_pushed()
	log_debug("Intro:notify_pushed")
	self:reset()
end

function M.Impl:notify_became_top()
end

function M.Impl:notify_popped()
	log_debug("Intro:notify_popped")
end

function M.Impl:bind_gate(bind, ident, dt, kind)
	if kind == Bind.Kind.Release then
		self:terminate()
		return false
	else
		return false
	end
end

function M.Impl:update(dt)
	if State.paused then
		return
	end

	if self.mode == Mode.Stay then
		if self.stay_timer:update(dt) then
			self.mode = Mode.Out
			if self:is_last() then
				self.fmode_out_bg.animator:reset(
					self:current_seq().fade +
					ternary(not self:is_soft(), 0.25, 0.0)
				)
			end
			self:animator():reset(self:current_seq().fade)
		end
	else
		if self:is_finishing() then
			if self.fmode_out_bg.animator:update(dt) then
				self:terminate()
			end
		end
		if	not self:is_seq_finished() and
			self:animator():update(dt)
		then
			if self.mode == Mode.In then
				self.mode = Mode.Stay
				self.stay_timer:reset(self:current_seq().stay)
			else
				self.seq_idx = self.seq_idx + 1
				if not self:is_seq_finished() then
					self.mode = Mode.In
					self:animator():reset(self:current_seq().fade)
				end
			end
		end
	end
end

function M.Impl:render()
	Gfx.setColor(
		0,0,0,
		ternary(
			self:is_soft(),
			self.fmode_out_bg.alpha,
			255
		)
	)
	Gfx.rectangle("fill",
		0,0,
		Core.display_size.x, Core.display_size.y
	)
	Gfx.setColor(
		255,255,255,
		self.mode == Mode.Stay and 255 or self:fmode().alpha
	)
	if not self:is_seq_finished() then
		local quad = self.atlas[self:current_seq().name]
		local _, _, w, h = quad:getViewport()
		Gfx.draw(
			self.atlas.tex,
			quad,
			Core.display_size_half.x - (w / 2),
			Core.display_size_half.y - (h / 2)
		)
	end
end

-- IntroScene interface

local function __static_init()
end

set_functable(M,
	function(_, seq, atlas, soft, transparent)
		__static_init()

		local impl = M.Impl(seq, atlas, soft)
		return Scene(impl, nil, transparent)
	end
)

return M
