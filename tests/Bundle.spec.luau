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
			Label = { Color = "label", Position = Vector2.new(-3, -3), Visible = false },
			SelectedLabel = { Color = "selected", Position = Vector2.new(-4, -4), Visible = false },
		},
	})
	segmented:setLayout({ Position = Vector2.new(10, 20), Size = Vector2.new(100, 20) })
	segmented:setVisible(false)
	assert(canvas:getElements()[3]:get("Visible") == false)
	segmented:setVisible(true)
	assert(canvas:getElements()[2]:get("Position") == Vector2.new(10, 20))
	assert(canvas:getElements()[3]:get("Position") == Vector2.new(10, 20))
	assert(canvas:getElements()[4]:get("Color") == "selected")
	assert(canvas:getElements()[4]:get("Position") == Vector2.new(10, 20))
	assert(canvas:getElements()[4]:get("Visible") == true)
	segmented:setValue("b")
	assert(canvas:getElements()[4]:get("Color") == "label")
	assert(canvas:getElements()[6]:get("Color") == "selected")

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

	local unsupportedFake = FakeDrawing.new()
	local unsupportedRuntime = Limn.new({
		Drawing = unsupportedFake.library,
		Vector2 = Vector2,
		SupportsPrimitive = function(kind: string): boolean
			return kind ~= "Circle"
		end,
	})
	local unsupportedCanvas = unsupportedRuntime:createCanvas()
	local unsupportedOk, unsupportedMessage = pcall(function()
		unsupportedRuntime:createSegmentedControl(unsupportedCanvas, {
			Position = Vector2.new(0, 0),
			Size = Vector2.new(20, 10),
			CornerRadius = 4,
			Options = { { Value = "a" } },
		})
	end)
	assert(not unsupportedOk)
	assert(
		string.find(tostring(unsupportedMessage), "CornerRadius requires Circle support", 1, true)
	)
	assert(#unsupportedCanvas:getElements() == 0 and #unsupportedFake.objects == 0)

	local roundedFake = FakeDrawing.new()
	local roundedRuntime = Limn.new({ Drawing = roundedFake.library, Vector2 = Vector2 })
	local roundedCanvas = roundedRuntime:createCanvas()
	local rounded = roundedRuntime:createSegmentedControl(roundedCanvas, {
		Position = Vector2.new(0, 40),
		Size = Vector2.new(80, 20),
		CornerRadius = 6,
		Options = {
			{ Value = "a", Label = "A" },
			{ Value = "b", Label = "B" },
		},
		Value = "a",
		Style = {
			Option = { Color = "option" },
			Selected = { Color = "selected" },
			Label = { Color = "label" },
			SelectedLabel = { Color = "selected-label" },
		},
	})
	assert(#roundedCanvas:getElements() == 22)
	assert(roundedCanvas:getElements()[3].Kind == "Circle")
	assert(roundedCanvas:getElements()[3]:get("Position") == Vector2.new(6, 46))
	assert(roundedCanvas:getElements()[3]:get("Radius") == 6)
	assert(roundedCanvas:getElements()[14]:get("Color") == "selected-label")
	rounded:setValue("b")
	assert(roundedCanvas:getElements()[14]:get("Color") == "label")
	assert(roundedCanvas:getElements()[22]:get("Color") == "selected-label")
	rounded:setLayout({ Position = Vector2.new(10, 40), Size = Vector2.new(20, 8) })
	assert(roundedCanvas:getElements()[3]:get("Position") == Vector2.new(14, 44))
	assert(roundedCanvas:getElements()[3]:get("Radius") == 4)
	rounded:setVisible(false)
	for _, element in roundedCanvas:getElements() do
		assert(element:get("Visible") == false)
	end
	rounded:setVisible(true)
	assert(roundedCanvas:getElements()[22]:get("Color") == "selected-label")
	roundedCanvas:destroy()
	for _, object in roundedFake.objects do
		assert(object.removed)
	end
end
