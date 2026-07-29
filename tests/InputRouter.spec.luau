--!strict

local roblox = require("@lune/roblox")
local FakeDrawing = require("./support/FakeDrawing")
local Limn = require("../src/Limn")

local Vector2 = roblox.Vector2

return function()
	local fake = FakeDrawing.new()
	local canvas = Limn.new({ Drawing = fake.library }):createCanvas()
	local lower = canvas:create("Square", {
		Position = Vector2.new(0, 0),
		Size = Vector2.new(100, 100),
		Visible = true,
		ZIndex = 1,
	}, { interactive = true })
	local upper = canvas:create("Square", {
		Position = Vector2.new(20, 20),
		Size = Vector2.new(100, 100),
		Visible = true,
		ZIndex = 2,
	}, { interactive = true })

	local entered = 0
	local left = 0
	local pressed = 0
	local dragged = 0
	local clicked = 0

	upper.PointerEntered:Connect(function()
		entered += 1
	end)
	upper.PointerLeft:Connect(function()
		left += 1
	end)
	upper.PointerDown:Connect(function()
		pressed += 1
	end)
	upper.Dragged:Connect(function()
		dragged += 1
	end)
	upper.Clicked:Connect(function()
		clicked += 1
	end)

	canvas:dispatchPointer({
		phase = "move",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = false,
	})
	assert(entered == 1)

	canvas:dispatchPointer({
		phase = "down",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = false,
	})
	canvas:dispatchPointer({
		phase = "move",
		position = Vector2.new(150, 150),
		pointerId = "mouse",
		processed = false,
	})
	assert(pressed == 1)
	assert(dragged == 1)
	assert(left == 1)

	canvas:dispatchPointer({
		phase = "up",
		position = Vector2.new(150, 150),
		pointerId = "mouse",
		processed = false,
	})
	assert(clicked == 0)

	canvas:dispatchPointer({
		phase = "down",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = true,
	})
	assert(pressed == 1)

	canvas:dispatchPointer({
		phase = "down",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = false,
	})
	canvas:dispatchPointer({
		phase = "up",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = false,
	})
	assert(clicked == 1)

	assert(lower ~= upper)
	canvas:destroy()
end
