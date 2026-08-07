--!strict

local roblox = require("@lune/roblox")
local Limn = require("../dist/Limn")
local FakeDrawing = require("./support/FakeDrawing")

local Vector2 = roblox.Vector2

local function newSignal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			table.insert(listeners, callback)
			return {
				Connected = true,
				Disconnect = function(connection)
					connection.Connected = false
					local index = table.find(listeners, callback)
					if index then
						table.remove(listeners, index)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(listeners) do
				callback(...)
			end
		end,
	}
end

local fake = FakeDrawing.new()
local paintSignal = newSignal()
local immediate = {
	GetPaint = function()
		return paintSignal
	end,
}
local runtime = Limn.new({
	Drawing = fake.library,
	DrawingImmediate = immediate,
	Vector2 = Vector2,
	Input = {
		MapPosition = function(position)
			return Vector2.new(position.X - 100, position.Y - 50)
		end,
	},
})
assert(runtime:supportsPrimitive("Square"))
local canvas = runtime:createCanvas()
local card = canvas:create("Square", {
	Position = Vector2.new(8, 8),
	Size = Vector2.new(80, 40),
	Visible = true,
	ZIndex = 5,
}, {
	interactive = true,
})

local clicks = 0
card.Clicked:Connect(function()
	clicks += 1
end)

local input = {
	InputBegan = newSignal(),
	InputChanged = newSignal(),
	InputEnded = newSignal(),
}
canvas:bindInput(input)

local mouse = {
	UserInputType = "MouseButton1",
	Position = Vector2.new(120, 70),
}
local capturedPaints = 0
local capturedPosition = Vector2.new(0, 0)
canvas:paintCaptured(card, 6, function(painter, event)
	assert(painter == immediate)
	capturedPaints += 1
	capturedPosition = event.position
end)

local segmented = runtime:createSegmentedControl(canvas, {
	Position = Vector2.new(8, 64),
	Size = Vector2.new(120, 24),
	ZIndex = 7,
	Options = {
		{ Value = "low", Label = "Low" },
		{ Value = "high", Label = "High" },
	},
	Value = "low",
	Style = {
		Frame = { Visible = true, Filled = true },
		Option = { Visible = true, Filled = true },
		Label = { Color = "label", Visible = true },
		SelectedLabel = { Color = "selected-label" },
	},
})
local segmentedChanges = 0
segmented.Changed:Connect(function()
	segmentedChanges += 1
end)
canvas:dispatchPointer({
	phase = "down",
	position = Vector2.new(100, 76),
	pointerId = "manual-segment",
	processed = false,
})
canvas:dispatchPointer({
	phase = "up",
	position = Vector2.new(100, 76),
	pointerId = "manual-segment",
	processed = false,
})
assert(
	segmented:getValue() == "high"
		and segmentedChanges == 1
		and canvas:getElements()[6]:get("Color") == "selected-label"
)
input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = { Name = "Left" } }, false)
input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = { Name = "Enter" } }, false)
assert(
	segmented:getValue() == "low"
		and segmentedChanges == 2
		and canvas:getElements()[4]:get("Color") == "selected-label"
		and canvas:getElements()[6]:get("Color") == "label"
)
segmented:setLayout({
	Position = Vector2.new(8, 128),
	Size = Vector2.new(120, 24),
})
segmented:setVisible(false)
assert(segmented:getValue() == "low" and segmentedChanges == 2)
segmented:setVisible(true)

local rounded = runtime:createSegmentedControl(canvas, {
	Position = Vector2.new(8, 192),
	Size = Vector2.new(120, 24),
	ZIndex = 7,
	CornerRadius = 12,
	Options = {
		{ Value = "low", Label = "Low" },
		{ Value = "high", Label = "High" },
	},
	Value = "low",
	Style = {
		Frame = { Color = "rounded-frame", Visible = true, Filled = true },
		Option = { Color = "option", Visible = true, Filled = true },
		Selected = { Color = "selected" },
		Hovered = { Color = "hovered" },
		Focused = { Transparency = 0.8 },
		Disabled = { Color = "disabled", Transparency = 0.4 },
		Label = { Color = "label", Visible = true },
		SelectedLabel = { Color = "selected-label" },
	},
})
assert(#canvas:getElements() == 28)
assert(canvas:getElements()[9].Kind == "Circle" and canvas:getElements()[9]:get("Radius") == 12)
canvas:dispatchPointer({
	phase = "down",
	position = Vector2.new(100, 204),
	pointerId = "manual-rounded",
	processed = false,
})
canvas:dispatchPointer({
	phase = "up",
	position = Vector2.new(100, 204),
	pointerId = "manual-rounded",
	processed = false,
})
assert(
	rounded:getValue() == "high"
		and canvas:getElements()[22]:get("Color") == "hovered"
		and canvas:getElements()[28]:get("Color") == "selected-label"
)
rounded:setValue("low")
rounded:setLayout({ Position = Vector2.new(8, 224), Size = Vector2.new(20, 8) })
assert(canvas:getElements()[9]:get("Position") == Vector2.new(12, 228))
assert(canvas:getElements()[9]:get("Radius") == 4)
rounded:setDisabled(true)
assert(canvas:getElements()[14]:get("Color") == "disabled")
assert(canvas:getElements()[20]:get("Color") == "selected-label")
rounded:setVisible(false)
assert(canvas:getElements()[9]:get("Visible") == false)
rounded:setVisible(true)
assert(canvas:getElements()[20]:get("Color") == "selected-label")

local keybind = runtime:createKeybindControl(canvas, {
	Position = Vector2.new(8, 96),
	Size = Vector2.new(120, 24),
	ZIndex = 7,
	Label = "Action",
	Value = "RightShift",
	Style = {
		Frame = { Visible = true, Filled = true },
		Label = { Visible = true },
		Value = { Visible = true },
	},
})
canvas:dispatchPointer({
	phase = "down",
	position = Vector2.new(20, 108),
	pointerId = "manual-keybind",
	processed = false,
})
canvas:dispatchPointer({
	phase = "up",
	position = Vector2.new(20, 108),
	pointerId = "manual-keybind",
	processed = false,
})
assert(keybind:getState() == "listening")
input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = { Name = "Q" } }, false)
assert(keybind:getValue() == "Q" and keybind:getDisplayValue() == "Q")
keybind:begin()
input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = { Name = "Escape" } }, false)
assert(keybind:getValue() == "Q")
keybind:clear()
assert(keybind:getValue() == nil)
keybind:setLayout({
	Position = Vector2.new(8, 160),
	Size = Vector2.new(120, 24),
})
keybind:begin()
keybind:setVisible(false)
assert(keybind:getState() == "idle" and keybind:getValue() == nil)
keybind:setVisible(true)
input.InputBegan:Fire(mouse, true)
input.InputEnded:Fire(mouse, true)
paintSignal:Fire()
assert(clicks == 0)
assert(capturedPaints == 0)
input.InputBegan:Fire(mouse, false)
input.InputChanged:Fire({
	UserInputType = "MouseMovement",
	Position = Vector2.new(140, 80),
}, false)
paintSignal:Fire()
assert(capturedPaints == 1)
assert(capturedPosition == Vector2.new(40, 30))
input.InputEnded:Fire(mouse, false)
paintSignal:Fire()

assert(clicks == 1)
assert(capturedPaints == 1)
canvas:destroy()
for _, object in fake.objects do
	assert(object.removed)
end
input.InputBegan:Fire(mouse, false)
input.InputEnded:Fire(mouse, false)
input.InputBegan:Fire({ UserInputType = "Keyboard", KeyCode = { Name = "G" } }, false)
paintSignal:Fire()
assert(clicks == 1)
assert(capturedPaints == 1)
assert(keybind:getValue() == nil)
print(
	"MANUAL PASS bundled controls -> rounded layout/state -> visibility -> keyboard rebind -> captured paint -> cleanup"
)
