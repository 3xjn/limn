--!strict

export type Point = {
	X: number,
	Y: number,
}

type Properties = { [string]: any }

local Geometry = {}

local function distanceSquared(a: Point, b: Point): number
	local x = a.X - b.X
	local y = a.Y - b.Y
	return x * x + y * y
end

local function pointInTriangle(point: Point, a: Point, b: Point, c: Point): boolean
	local ab = (point.X - b.X) * (a.Y - b.Y) - (a.X - b.X) * (point.Y - b.Y)
	local bc = (point.X - c.X) * (b.Y - c.Y) - (b.X - c.X) * (point.Y - c.Y)
	local ca = (point.X - a.X) * (c.Y - a.Y) - (c.X - a.X) * (point.Y - a.Y)
	local hasNegative = ab < 0 or bc < 0 or ca < 0
	local hasPositive = ab > 0 or bc > 0 or ca > 0
	return not (hasNegative and hasPositive)
end

local function pointNearLine(point: Point, from: Point, to: Point, tolerance: number): boolean
	local dx = to.X - from.X
	local dy = to.Y - from.Y
	local lengthSquared = dx * dx + dy * dy
	if lengthSquared == 0 then
		return distanceSquared(point, from) <= tolerance * tolerance
	end

	local projection = ((point.X - from.X) * dx + (point.Y - from.Y) * dy) / lengthSquared
	local clamped = math.clamp(projection, 0, 1)
	local closest = {
		X = from.X + clamped * dx,
		Y = from.Y + clamped * dy,
	}
	return distanceSquared(point, closest) <= tolerance * tolerance
end

local function pointInRectangle(point: Point, position: Point, size: Point): boolean
	return point.X >= position.X
		and point.Y >= position.Y
		and point.X <= position.X + size.X
		and point.Y <= position.Y + size.Y
end

function Geometry.contains(
	kind: string,
	properties: Properties,
	point: Point,
	padding: number?
): boolean
	local extra = padding or 0

	if kind == "Square" or kind == "Image" then
		local position = properties.Position :: Point
		local size = properties.Size :: Point
		return pointInRectangle(point, {
			X = position.X - extra,
			Y = position.Y - extra,
		}, {
			X = size.X + extra * 2,
			Y = size.Y + extra * 2,
		})
	elseif kind == "Text" then
		local position = properties.Position :: Point
		local bounds = properties.TextBounds :: Point
		if properties.Center or properties.Centered then
			position = {
				X = position.X - bounds.X / 2,
				Y = position.Y,
			}
		end
		return pointInRectangle(point, position, bounds)
	elseif kind == "Circle" then
		local radius = properties.Radius + extra
		return distanceSquared(point, properties.Position) <= radius * radius
	elseif kind == "Line" then
		return pointNearLine(
			point,
			properties.From,
			properties.To,
			math.max(properties.Thickness / 2, 1) + extra
		)
	elseif kind == "Triangle" then
		return pointInTriangle(point, properties.PointA, properties.PointB, properties.PointC)
	elseif kind == "Quad" then
		return pointInTriangle(point, properties.PointA, properties.PointB, properties.PointC)
			or pointInTriangle(point, properties.PointA, properties.PointC, properties.PointD)
	end

	return false
end

return Geometry
