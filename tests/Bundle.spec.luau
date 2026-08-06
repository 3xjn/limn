--!strict

local FakeDrawing = require("./support/FakeDrawing")
local Limn = require("../dist/Limn")
local roblox = require("@lune/roblox")

local Vector2 = roblox.Vector2

return function()
	local fake = FakeDrawing.new()
	local runtime = Limn.new({ Drawing = fake.library, Vector2 = Vector2 })
	assert(runtime:supportsPrimitive("Square"))
	local canvas = runtime:createCanvas()
	canvas:create("Square", {
		Visible = true,
	})
	assert(#canvas:getElements() == 1)
	local segmented = runtime:createSegmentedControl(canvas, {
		Position = Vector2.new(0, 20),
		Size = Vector2.new(80, 20),
		Options = {
			{ Value = "a", Label = "A" },
			{ Value = "b", Label = "B" },
		},
		Style = {
			Frame = { Position = Vector2.new(-1, -1), Size = Vector2.new(1, 1) },
			Option = { Position = Vector2.new(-2, -2), Size = Vector2.new(2, 2) },
		},
	})
	segmented:setLayout({ Position = Vector2.new(10, 20), Size = Vector2.new(100, 20) })
	segmented:setVisible(false)
	assert(canvas:getElements()[3]:get("Visible") == false)
	segmented:setVisible(true)
	assert(canvas:getElements()[2]:get("Position") == Vector2.new(10, 20))
	assert(canvas:getElements()[3]:get("Position") == Vector2.new(10, 20))

	local keybind = runtime:createKeybindControl(canvas, {
		Position = Vector2.new(0, 50),
		Size = Vector2.new(80, 20),
		Value = "Q",
		Style = {
			Frame = { Position = Vector2.new(-3, -3), Size = Vector2.new(3, 3) },
			Value = { Position = Vector2.new(-4, -4) },
		},
	})
	keybind:setLayout({ Position = Vector2.new(10, 50), Size = Vector2.new(100, 20) })
	keybind:setVisible(false)
	assert(keybind:getValue() == "Q" and keybind:getState() == "idle")
	keybind:setVisible(true)
	assert(canvas:getElements()[7]:get("Position") == Vector2.new(10, 50))
	assert(canvas:getElements()[8]:get("Position") == Vector2.new(60, 50))
	canvas:destroy()
	assert(fake.objects[1].removed)
	for _, object in fake.objects do
		assert(object.removed)
	end
end
