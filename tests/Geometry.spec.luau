--!strict

local roblox = require("@lune/roblox")
local Geometry = require("../src/Geometry")

local Vector2 = roblox.Vector2

return function()
	assert(Geometry.contains("Square", {
		Position = Vector2.new(10, 10),
		Size = Vector2.new(40, 20),
	}, Vector2.new(20, 20)))
	assert(not Geometry.contains("Square", {
		Position = Vector2.new(10, 10),
		Size = Vector2.new(40, 20),
	}, Vector2.new(60, 20)))

	assert(Geometry.contains("Circle", {
		Position = Vector2.new(50, 50),
		Radius = 10,
	}, Vector2.new(56, 56)))
	assert(not Geometry.contains("Circle", {
		Position = Vector2.new(50, 50),
		Radius = 10,
	}, Vector2.new(61, 50)))

	assert(Geometry.contains("Triangle", {
		PointA = Vector2.new(0, 0),
		PointB = Vector2.new(20, 0),
		PointC = Vector2.new(10, 20),
	}, Vector2.new(10, 5)))

	assert(Geometry.contains("Line", {
		From = Vector2.new(0, 0),
		To = Vector2.new(100, 0),
		Thickness = 2,
	}, Vector2.new(50, 2), 2))
	assert(not Geometry.contains("Line", {
		From = Vector2.new(0, 0),
		To = Vector2.new(100, 0),
		Thickness = 2,
	}, Vector2.new(50, 5), 2))
end
