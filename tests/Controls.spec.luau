--!strict

local roblox = require("@lune/roblox")
local FakeDrawing = require("./support/FakeDrawing")
local Limn = require("../src/Limn")

local Vector2 = roblox.Vector2

local function newSignal()
	local listeners = {}
	local signal = {}

	function signal:Connect(callback)
		table.insert(listeners, callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			if not self.Connected then
				return
			end
			self.Connected = false
			local index = table.find(listeners, callback)
			if index then
				table.remove(listeners, index)
			end
		end
		return connection
	end

	function signal:Fire(...)
		for _, callback in table.clone(listeners) do
			callback(...)
		end
	end

	return signal
end

local function newInputService()
	return {
		InputBegan = newSignal(),
		InputChanged = newSignal(),
		InputEnded = newSignal(),
	}
end

local function pointer(phase: "move" | "down" | "up", x: number, y: number, processed: boolean?)
	return {
		phase = phase,
		position = Vector2.new(x, y),
		pointerId = "mouse",
		processed = processed == true,
	}
end

local function key(name: string)
	return {
		UserInputType = "Keyboard",
		KeyCode = { Name = name },
	}
end

return function()
	local fake = FakeDrawing.new()
	local input = newInputService()
	local runtime = Limn.new({
		Drawing = fake.library,
		Vector2 = Vector2,
	})
	local canvas = runtime:createCanvas()
	canvas:bindInput(input)
	local focusTarget = canvas:create("Square", {
		Position = Vector2.new(200, 10),
		Size = Vector2.new(20, 20),
		Visible = true,
	}, { interactive = true })
	focusTarget:setFocusable(true)
	local focused = 0
	local focusLost = 0
	local receivedKey: string? = nil
	focusTarget.Focused:Connect(function()
		focused += 1
	end)
	focusTarget.FocusLost:Connect(function()
		focusLost += 1
	end)
	focusTarget.KeyDown:Connect(function(_: any, normalized: string)
		receivedKey = normalized
	end)
	canvas:dispatchPointer(pointer("down", 205, 15))
	assert(canvas:getFocusedElement() == focusTarget and focused == 1)
	input.InputBegan:Fire(key("P"), true)
	assert(receivedKey == nil)
	input.InputBegan:Fire(key("P"), false)
	assert(receivedKey == "P")
	focusTarget:destroy()
	assert(canvas:getFocusedElement() == nil and focusLost == 1)

	local segmentedStyle = {
		Frame = { Color = "frame" },
		Option = { Color = "option" },
		Selected = { Color = "selected" },
		Hovered = { Color = "hovered" },
		Focused = { Transparency = 0.8 },
		Disabled = { Transparency = 0.2 },
		Label = {
			Color = "label",
			Transparency = 0.25,
			Position = Vector2.new(-50, -50),
			ZIndex = 500,
			Visible = false,
		},
		SelectedLabel = {
			Color = "selected-label",
			Transparency = 0.75,
			Position = Vector2.new(-60, -60),
			ZIndex = 600,
			Visible = false,
		},
	}
	local segmented = runtime:createSegmentedControl(canvas, {
		Position = Vector2.new(10, 10),
		Size = Vector2.new(120, 24),
		ZIndex = 10,
		Options = {
			{ Value = "low", Label = "Low" },
			{ Value = "high", Label = "High" },
		},
		Value = "low",
		Style = segmentedStyle,
	})
	local segmentedPointerDown = 0
	canvas:getElements()[4].PointerDown:Connect(function()
		segmentedPointerDown += 1
	end)

	local changes = {}
	segmented.Changed:Connect(function(value, previous, source)
		table.insert(changes, { value = value, previous = previous, source = source })
	end)

	assert(segmented:getValue() == "low")
	assert(segmented:getState() == "idle")
	assert(fake.objects[3].ZIndex == 11)
	assert(fake.objects[5].ZIndex == 11)
	assert(canvas:getElements()[4]:contains(Vector2.new(105, 20)))
	assert(#canvas:getElements() == 5)
	assert(canvas:getElements()[3]:get("Color") == "selected-label")
	assert(canvas:getElements()[3]:get("Transparency") == 0.75)
	assert(canvas:getElements()[3]:get("Position") == Vector2.new(10, 10))
	assert(
		canvas:getElements()[3]:get("ZIndex") == 12
			and canvas:getElements()[3]:get("Visible") == true
	)
	assert(canvas:getElements()[5]:get("Color") == "label")
	assert(canvas:getElements()[5]:get("Transparency") == 0.25)

	canvas:dispatchPointer(pointer("down", 105, 20))
	assert(canvas:getFocusedElement() ~= nil)
	canvas:dispatchPointer(pointer("up", 105, 20))
	assert(segmented:getValue() == "high")
	assert(
		changes[1].previous == "low"
			and changes[1].value == "high"
			and changes[1].source == "pointer"
	)
	assert(canvas:getFocusedElement() ~= nil)
	assert(segmented:getState() == "focused")
	assert(canvas:getElements()[4]:get("Color") == "hovered")
	assert(canvas:getElements()[4]:get("Transparency") == 0.8)
	assert(canvas:getElements()[5]:get("Color") == "selected-label")
	assert(canvas:getElements()[5]:get("Transparency") == 0.75)
	assert(canvas:getElements()[3]:get("Color") == "label")
	assert(#canvas:getElements() == 5)

	segmented:setValue("low")
	assert(changes[2].source == "programmatic")
	assert(canvas:getElements()[3]:get("Color") == "selected-label")
	assert(canvas:getElements()[5]:get("Color") == "label")
	assert(#canvas:getElements() == 5)

	input.InputBegan:Fire(key("Right"), true)
	assert(segmented:getValue() == "low")
	input.InputBegan:Fire(key("Right"), false)
	input.InputBegan:Fire(key("Enter"), false)
	assert(segmented:getValue() == "high")
	assert(changes[3].source == "keyboard")
	assert(canvas:getElements()[5]:get("Color") == "selected-label")
	segmented:setValue("low")
	assert(changes[4].source == "programmatic")

	segmented:setDisabled(true)
	assert(segmented:getState() == "disabled")
	assert(canvas:getElements()[2]:get("Color") == "selected")
	assert(canvas:getElements()[2]:get("Transparency") == 0.2)
	assert(canvas:getElements()[3]:get("Color") == "selected-label")
	canvas:dispatchPointer(pointer("down", 105, 20))
	canvas:dispatchPointer(pointer("up", 105, 20))
	input.InputBegan:Fire(key("Right"), false)
	input.InputBegan:Fire(key("Enter"), false)
	assert(segmented:getValue() == "low")
	segmented:setDisabled(false)
	segmentedStyle.Frame.Position = Vector2.new(-10, -10)
	segmentedStyle.Frame.Size = Vector2.new(1, 1)
	segmentedStyle.Option.Position = Vector2.new(-20, -20)
	segmentedStyle.Option.Size = Vector2.new(2, 2)
	segmentedStyle.Label.Position = Vector2.new(-70, -70)
	segmentedStyle.Label.ZIndex = 700
	segmentedStyle.Label.Visible = false
	segmentedStyle.SelectedLabel.Position = Vector2.new(-80, -80)
	segmentedStyle.SelectedLabel.ZIndex = 800
	segmentedStyle.SelectedLabel.Visible = false
	local layoutChanges = #changes
	segmented:setLayout({
		Position = Vector2.new(140, 10),
		Size = Vector2.new(100, 60),
		Layout = function(index: number)
			return {
				Position = Vector2.new(140, 10 + (index - 1) * 30),
				Size = Vector2.new(100, 30),
				LabelPosition = Vector2.new(150, 14 + (index - 1) * 30),
			}
		end,
	})
	assert(canvas:getElements()[1]:get("Position") == Vector2.new(140, 10))
	assert(canvas:getElements()[1]:get("Size") == Vector2.new(100, 60))
	assert(canvas:getElements()[2]:get("Position") == Vector2.new(140, 10))
	assert(canvas:getElements()[2]:get("Size") == Vector2.new(100, 30))
	assert(canvas:getElements()[3]:get("Position") == Vector2.new(150, 14))
	assert(
		canvas:getElements()[3]:get("ZIndex") == 12
			and canvas:getElements()[3]:get("Visible") == true
	)
	assert(canvas:getElements()[5]:get("Position") == Vector2.new(150, 44))
	assert(#changes == layoutChanges and segmented:getValue() == "low")
	segmented:setLayout({
		Position = Vector2.new(140, 10),
		Size = Vector2.new(100, 20),
	})
	assert(canvas:getElements()[4]:get("Position") == Vector2.new(190, 10))
	assert(canvas:getElements()[4]:get("Size") == Vector2.new(50, 20))
	assert(#changes == layoutChanges)

	segmentedPointerDown = 0
	canvas:dispatchPointer(pointer("down", 195, 15))
	assert(segmentedPointerDown == 1)
	segmented:setVisible(false)
	canvas:dispatchPointer(pointer("up", 195, 15))
	assert(segmented:getValue() == "low" and #changes == layoutChanges)
	assert(canvas:getFocusedElement() == nil)
	assert(not canvas:getElements()[2]:isInteractive())
	canvas:dispatchPointer(pointer("down", 195, 15))
	canvas:dispatchPointer(pointer("up", 195, 15))
	assert(segmentedPointerDown == 1 and canvas:getFocusedElement() == nil)
	assert(segmented:getValue() == "low" and #changes == layoutChanges)
	for index = 1, 5 do
		assert(canvas:getElements()[index]:get("Visible") == false)
	end
	segmented:setVisible(true)
	assert(canvas:getElements()[2]:get("Visible") == true)
	assert(canvas:getElements()[2]:get("Position") == Vector2.new(140, 10))
	assert(canvas:getElements()[2]:isInteractive())
	assert(canvas:getElements()[3]:get("Color") == "selected-label")
	assert(canvas:getElements()[3]:get("Position") == Vector2.new(140, 10))
	assert(canvas:getElements()[3]:get("Visible") == true)
	segmented:setDisabled(true)
	segmented:setVisible(false)
	segmented:setVisible(true)
	assert(segmented:getState() == "disabled" and segmented:getValue() == "low")
	assert(canvas:getElements()[1]:get("Position") == Vector2.new(140, 10))
	assert(canvas:getElements()[4]:get("Position") == Vector2.new(190, 10))
	assert(canvas:getElements()[3]:get("Color") == "selected-label")
	segmented:setDisabled(false)

	local keybindStyle = {
		Frame = { Color = "frame" },
		Focused = { Color = "focused" },
		Listening = { Color = "listening" },
		Disabled = { Transparency = 0.2 },
		Label = { Color = "label" },
		Value = {},
	}
	local keybind = runtime:createKeybindControl(canvas, {
		Position = Vector2.new(10, 50),
		Size = Vector2.new(120, 24),
		ZIndex = 20,
		Label = "Action",
		Value = "Enum.KeyCode.RightShift",
		Style = keybindStyle,
	})

	local bindings = {}
	keybind.Changed:Connect(function(value, previous, source)
		table.insert(bindings, { value = value, previous = previous, source = source })
	end)
	assert(keybind:getValue() == "RightShift")
	assert(keybind:getDisplayValue() == "Right Shift")
	assert(keybind:getState() == "idle")

	canvas:dispatchPointer(pointer("down", 20, 60))
	canvas:dispatchPointer(pointer("up", 20, 60))
	assert(keybind:getState() == "listening")
	input.InputBegan:Fire(key("Q"), true)
	assert(keybind:getValue() == "RightShift")
	input.InputBegan:Fire(key("Q"), false)
	assert(keybind:getValue() == "Q")
	assert(keybind:getDisplayValue() == "Q")
	assert(
		bindings[1].previous == "RightShift"
			and bindings[1].value == "Q"
			and bindings[1].source == "keyboard"
	)
	assert(keybind:getState() == "focused")

	keybind:begin()
	input.InputBegan:Fire(key("Escape"), false)
	assert(keybind:getValue() == "Q")
	assert(keybind:getState() == "focused")
	keybind:begin()
	input.InputBegan:Fire(key("Backspace"), false)
	assert(keybind:getValue() == nil)
	assert(bindings[2].value == nil and bindings[2].source == "clear")

	keybind:setDisabled(true)
	assert(keybind:getState() == "disabled")
	keybind:begin()
	input.InputBegan:Fire(key("F"), false)
	assert(keybind:getValue() == nil)
	keybind:setDisabled(false)
	keybindStyle.Frame.Position = Vector2.new(-30, -30)
	keybindStyle.Frame.Size = Vector2.new(3, 3)
	keybindStyle.Value.Position = Vector2.new(-40, -40)
	keybind:setLayout({
		Position = Vector2.new(150, 50),
		Size = Vector2.new(100, 24),
		Layout = {
			LabelPosition = Vector2.new(155, 54),
			ValuePosition = Vector2.new(205, 54),
		},
	})
	assert(canvas:getElements()[6]:get("Position") == Vector2.new(150, 50))
	assert(canvas:getElements()[6]:get("Size") == Vector2.new(100, 24))
	assert(canvas:getElements()[7]:get("Position") == Vector2.new(155, 54))
	assert(canvas:getElements()[8]:get("Position") == Vector2.new(205, 54))
	assert(#bindings == 2 and keybind:getValue() == nil)
	local keybindPointerDown = 0
	canvas:getElements()[6].PointerDown:Connect(function()
		keybindPointerDown += 1
	end)

	canvas:dispatchPointer(pointer("down", 160, 60))
	assert(keybindPointerDown == 1)
	keybind:setVisible(false)
	canvas:dispatchPointer(pointer("up", 160, 60))
	assert(keybind:getState() == "idle" and keybind:getValue() == nil)
	assert(canvas:getFocusedElement() == nil)
	assert(not canvas:getElements()[6]:isInteractive())
	canvas:dispatchPointer(pointer("down", 160, 60))
	canvas:dispatchPointer(pointer("up", 160, 60))
	assert(keybindPointerDown == 1 and canvas:getFocusedElement() == nil)
	assert(not keybind:begin())
	input.InputBegan:Fire(key("F"), false)
	assert(keybind:getState() == "idle" and keybind:getValue() == nil and #bindings == 2)
	for index = 6, 8 do
		assert(canvas:getElements()[index]:get("Visible") == false)
	end
	keybind:setVisible(true)
	assert(canvas:getElements()[6]:get("Position") == Vector2.new(150, 50))
	assert(canvas:getElements()[8]:get("Position") == Vector2.new(205, 54))
	keybind:begin()
	assert(keybind:getState() == "listening")
	keybind:setVisible(false)
	assert(keybind:getState() == "idle" and keybind:getValue() == nil)
	keybind:setDisabled(true)
	keybind:setVisible(true)
	assert(keybind:getState() == "disabled" and keybind:getValue() == nil)
	assert(canvas:getElements()[6]:get("Position") == Vector2.new(150, 50))
	assert(canvas:getElements()[8]:get("Position") == Vector2.new(205, 54))
	keybind:setDisabled(false)

	canvas:dispatchPointer(pointer("down", 160, 60))
	keybind:destroy()
	canvas:dispatchPointer(pointer("up", 160, 60))
	input.InputBegan:Fire(key("G"), false)
	assert(#bindings == 2)

	segmented:destroy()
	segmented:destroy()
	canvas:destroy()
	for _, object in fake.objects do
		assert(object.removed)
	end
end
