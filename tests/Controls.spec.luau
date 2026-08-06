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

	local segmented = runtime:createSegmentedControl(canvas, {
		Position = Vector2.new(10, 10),
		Size = Vector2.new(120, 24),
		ZIndex = 10,
		Options = {
			{ Value = "low", Label = "Low" },
			{ Value = "high", Label = "High" },
		},
		Value = "low",
		Style = {
			Frame = { Color = "frame" },
			Option = { Color = "option" },
			Selected = { Color = "selected" },
			Focused = { Transparency = 0.8 },
			Disabled = { Transparency = 0.2 },
			Label = { Color = "label" },
		},
	})

	local changes = {}
	segmented.Changed:Connect(function(value, previous, source)
		table.insert(changes, { value = value, previous = previous, source = source })
	end)

	assert(segmented:getValue() == "low")
	assert(segmented:getState() == "idle")
	assert(fake.objects[3].ZIndex == 11)
	assert(fake.objects[5].ZIndex == 11)
	assert(canvas:getElements()[4]:contains(Vector2.new(105, 20)))

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

	input.InputBegan:Fire(key("Left"), true)
	assert(segmented:getValue() == "high")
	input.InputBegan:Fire(key("Left"), false)
	input.InputBegan:Fire(key("Enter"), false)
	assert(segmented:getValue() == "low")
	assert(changes[2].source == "keyboard")

	segmented:setDisabled(true)
	assert(segmented:getState() == "disabled")
	canvas:dispatchPointer(pointer("down", 105, 20))
	canvas:dispatchPointer(pointer("up", 105, 20))
	input.InputBegan:Fire(key("Right"), false)
	input.InputBegan:Fire(key("Enter"), false)
	assert(segmented:getValue() == "low")
	segmented:setDisabled(false)

	local keybind = runtime:createKeybindControl(canvas, {
		Position = Vector2.new(10, 50),
		Size = Vector2.new(120, 24),
		ZIndex = 20,
		Label = "Action",
		Value = "Enum.KeyCode.RightShift",
		Style = {
			Frame = { Color = "frame" },
			Focused = { Color = "focused" },
			Listening = { Color = "listening" },
			Disabled = { Transparency = 0.2 },
			Label = { Color = "label" },
		},
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

	canvas:dispatchPointer(pointer("down", 20, 60))
	keybind:destroy()
	canvas:dispatchPointer(pointer("up", 20, 60))
	input.InputBegan:Fire(key("G"), false)
	assert(#bindings == 2)

	segmented:destroy()
	segmented:destroy()
	canvas:destroy()
	for _, object in fake.objects do
		assert(object.removed)
	end
end
