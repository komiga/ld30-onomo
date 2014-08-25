
require("src/Util")

local M = def_module("Math", nil)

-- class Vec2

Vec2 = class(Vec2)

function Vec2:__init(xv, y)
	if is_type(xv, Vec2) then
		type_assert(y, "nil")
		self:set(xv)
	else
		self:set(xv or 0, y or 0)
	end
end

function Vec2:set(xv, y)
	if is_type(xv, Vec2) then
		type_assert(y, "nil")
		self.x = xv.x
		self.y = xv.y
	else
		type_assert(xv, "number")
		type_assert(y, "number")
		self.x = xv
		self.y = y
	end
end

function Vec2:get()
	return self.x, self.y
end

function Vec2.__len(_)
	return 2
end

function Vec2.__tostring(l)
	return "(" .. l.x .. ", " .. l.y .. ")"
end

function Vec2.__eq(l, r)
	return l.x == r.x and l.y == r.y
end

function Vec2.__lt(l, r)
	return l.x < r.x and l.y < r.y
end

function Vec2.__le(l, r)
	return l.x <= r.x and l.y <= r.y
end

function Vec2.__unm(l)
	return Vec2(-l.x, -l.y)
end

function Vec2.__add(l, r)
	if is_type(r, Vec2) then
		return Vec2(l.x + r.x, l.y + r.y)
	else
		type_assert(r, "number")
		return Vec2(l.x + r, l.y + r)
	end
end

function Vec2.__sub(l, r)
	if is_type(r, Vec2) then
		return Vec2(l.x - r.x, l.y - r.y)
	else
		type_assert(r, "number")
		return Vec2(l.x - r, l.y - r)
	end
end

function Vec2.__mul(l, r)
	if is_type(r, Vec2) then
		return Vec2(l.x * r.x, l.y * r.y)
	else
		type_assert(r, "number")
		return Vec2(l.x * r, l.y * r)
	end
end

function Vec2.__div(l, r)
	if is_type(r, Vec2) then
		return Vec2(l.x / r.x, l.y / r.y)
	else
		type_assert(r, "number")
		return Vec2(l.x / r, l.y / r)
	end
end

function Vec2:dot(v)
	type_assert(v, Vec2)
	return self.x * v.x + self.y * v.y
end

function Vec2:length()
	return math.sqrt(self.x * self.x + self.y * self.y)
end

function Vec2:length2()
	return self.x * self.x + self.y * self.y
end

function Vec2:distance(v)
	type_assert(v, Vec2)
	local dx = v.x - self.x
	local dy = v.y - self.y
	return math.sqrt(dx * dx + dy * dy)
end

function Vec2:distance2(v)
	type_assert(v, Vec2)
	local dx = v.x - self.x
	local dy = v.y - self.y
	return dx * dx + dy * dy
end

function Vec2:normalize()
	local linverse = 1 / math.sqrt(self.x * self.x + self.y * self.y)
	self.x = self.x * linverse
	self.y = self.y * linverse
	return self
end

function Vec2:normalized()
	return Vec2(self):normalize()
end

function Vec2:rotate(theta)
	type_assert(theta, "number")
	local theta_sin = math.sin(theta)
	local theta_cos = math.cos(theta)
	self.x = self.x * theta_cos - self.y * theta_sin
	self.y = self.x * theta_sin + self.y * theta_cos
	return self
end

function Vec2:rotated(theta)
	return Vec2(self):rotate(theta)
end

function Vec2:perpendicular()
	return Vec2(-self.y, self.x)
end

function Vec2:angle_to(v)
	type_assert(v, Vec2)
	--return math.atan2(self.y, self.x) - math.atan2(v.x, v.y)
	return math.atan2(v.y - self.y, v.x - self.x)
end

-- Math interface

function M.lerp(v0, v1, t)
	return v0 * (1 - t) + v1 * t
end

function M.bezier_cubic(v0, v1, v2, v3, t)
	-- Brute force:
	--return Math.lerp(
	--	Math.lerp(Math.lerp(v0, v1, t), Math.lerp(v1, v2, t), t),
	--	Math.lerp(Math.lerp(v1, v2, t), Math.lerp(v2, v3, t), t),
	--	t
	--)

	-- Reduction
	local r = 1 - t
	local i2 = v2 * 3*r * t*t
	r = r*r
	return
		(v0 * r*r) +
		(v1 * r * 3*t) +
		i2 +
		(v3 * t*t*t)
end

return M
