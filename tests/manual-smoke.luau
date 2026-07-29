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
assert(fake.objects[1].removed)
assert(fake.objects[2].removed)
input.InputBegan:Fire(mouse, false)
input.InputEnded:Fire(mouse, false)
paintSignal:Fire()
assert(clicks == 1)
assert(capturedPaints == 1)
print("MANUAL PASS bundled capability -> captured paint -> mapped input -> cleanup")
