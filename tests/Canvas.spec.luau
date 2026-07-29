--!strict

local roblox = require("@lune/roblox")
local FakeDrawing = require("./support/FakeDrawing")
local Limn = require("../src/Limn")

local Color3 = roblox.Color3
local Vector2 = roblox.Vector2

return function()
	local fake = FakeDrawing.new()
	local limn = Limn.new({
		Drawing = fake.library,
	})
	local canvas = limn:createCanvas()
	local square = canvas:create("Square", {
		Color = Color3.fromRGB(20, 40, 60),
		Position = Vector2.new(10, 20),
		Size = Vector2.new(100, 50),
		Visible = true,
		ZIndex = 3,
	})

	assert(#canvas:getElements() == 1)
	assert(fake.objects[1].Visible)
	assert(fake.objects[1].Position == Vector2.new(10, 20))

	square:set("Position", Vector2.new(30, 40))
	assert(square:get("Position") == Vector2.new(30, 40))
	assert(square:contains(Vector2.new(40, 50)))

	square:destroy()
	square:destroy()
	assert(fake.objects[1].removed)
	assert(#canvas:getElements() == 0)

	canvas:create("Circle", {
		Position = Vector2.new(50, 50),
		Radius = 10,
		Visible = true,
	})
	canvas:clear()
	canvas:clear()
	assert(fake.objects[2].removed)
	assert(#canvas:getElements() == 0)

	canvas:destroy()
	canvas:destroy()
end
