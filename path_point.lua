--2d geometry solutions.

local sqrt, abs, cos, sin, min, max, atan2 =
	math.sqrt, math.abs, math.cos, math.sin, math.min, math.max, math.atan2

--the angle of a point relative to an origin point.
local function point_angle(x, y, cx, cy)
	return atan2(y - cy, x - cx)
end

--point at distance and angle from origin.
local function point_around(cx, cy, distance, angle)
	return
		cx + cos(angle) * distance,
		cy + sin(angle) * distance
end

--point rotated at an angle around origin.
local function point_rotate(x, y, cx, cy, angle)
	x, y = x - cx, y - cy
	local cs, sn = cos(angle), sin(angle)
	return
		cx + x * cs - y * sn,
		cy + y * cs + x * sn
end

--hypotenuse function: computes sqrt(x^2 + y^2) avoiding overflow and underflow cases.
local function hypot(x, y)
	if x == 0 and y == 0 then return 0 end
	x, y = abs(x), abs(y)
	local t = min(x, y)
	x = max(x, y)
	t = t / x
	return x * sqrt(1 + t^2)
end

local function point_distance(x1, y1, x2, y2) --the distance between two points
	return hypot(x2 - x1, y2 - y1)
end

local function point_distance2(x1, y1, x2, y2) --the distance between two points squared
	return (x2 - x1)^2 + (y2 - y1)^2
end

local function reflect_point(x, y, cx, cy) --point reflected through origin (rotated 180deg around origin)
	return 2 * cx - x, 2 * cy - y
end

local function reflect_scale_point(x, y, cx, cy, length) --point reflected through origin and resized
	local d = hypot(x - cx, y - cy)
	if d == 0 then return cx, cy end
	local scale = length / d
	return
		cx + (cx - x) * scale,
		cy + (cy - y) * scale
end

return {
	angle = point_angle,
	around = point_around,
	rotate = point_rotate,
	hypot = hypot,
	distance = point_distance,
	distance2 = point_distance2,
	reflect = reflect_point,
	reflect_scale = reflect_scale_point,
}

