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

return function()
	local fake = FakeDrawing.new()
	local paint = newSignal()
	local immediate = {
		GetPaint = function()
			return paint
		end,
	}
	local canvas = Limn.new({
		Drawing = fake.library,
		DrawingImmediate = immediate,
		Vector2 = Vector2,
	}):createCanvas()

	local input = newInputService()
	canvas:bindInput(input)

	local element = canvas:create("Square", {
		Position = Vector2.new(0, 0),
		Size = Vector2.new(100, 100),
		Visible = true,
	}, { interactive = true })
	local clicked = 0
	element.Clicked:Connect(function()
		clicked += 1
	end)

	local mouse = {
		UserInputType = "MouseButton1",
		Position = Vector2.new(20, 20),
	}
	input.InputBegan:Fire(mouse, false)
	input.InputEnded:Fire(mouse, false)
	assert(clicked == 1)

	local paintCount = 0
	canvas:paint(4, function(painter)
		assert(painter == immediate)
		paintCount += 1
	end)
	paint:Fire()
	assert(paintCount == 1)

	canvas:destroy()
	input.InputBegan:Fire(mouse, false)
	input.InputEnded:Fire(mouse, false)
	paint:Fire()
	assert(clicked == 1)
	assert(paintCount == 1)

	local probeCalls = 0
	local probeRemovals = 0
	local drawing = {}
	function drawing.new(kind: string)
		probeCalls += 1
		if kind == "Quad" then
			error("not implemented")
		end
		local object = {}
		function object:Remove()
			probeRemovals += 1
		end
		return object
	end

	local capabilityRuntime = Limn.new({
		Drawing = drawing,
	})
	assert(capabilityRuntime:supportsPrimitive("Square"))
	assert(probeCalls == 1)
	assert(probeRemovals == 1)
	assert(capabilityRuntime:supportsPrimitive("Square"))
	assert(probeCalls == 1)
	assert(not capabilityRuntime:supportsPrimitive("Quad"))
	assert(probeCalls == 2)
	assert(not capabilityRuntime:supportsPrimitive("Quad"))
	assert(probeCalls == 2)
	local unsupportedCanvas = capabilityRuntime:createCanvas()
	local created, createError = pcall(function()
		unsupportedCanvas:create("Quad")
	end)
	assert(not created)
	assert(string.find(tostring(createError), 'unsupported drawing kind "Quad"', 1, true))
	assert(probeCalls == 2)
	unsupportedCanvas:destroy()

	local detectorCalls = 0
	local detectorRuntime = Limn.new({
		Drawing = fake.library,
		SupportsPrimitive = function(kind: string): boolean
			detectorCalls += 1
			return kind == "Text"
		end,
	})
	assert(detectorRuntime:supportsPrimitive("Text"))
	assert(not detectorRuntime:supportsPrimitive("Image"))
	assert(detectorCalls == 2)

	local mappedFake = FakeDrawing.new()
	local mappedInput = newInputService()
	local mappedCanvas = Limn.new({
		Drawing = mappedFake.library,
		Vector2 = Vector2,
		Input = {
			MapPosition = function(position)
				return Vector2.new(position.X - 100, position.Y - 50)
			end,
		},
	}):createCanvas()
	mappedCanvas:bindInput(mappedInput)

	local mappedElement = mappedCanvas:create("Square", {
		Position = Vector2.new(0, 0),
		Size = Vector2.new(40, 40),
		Visible = true,
	}, { interactive = true })
	local mappedClicks = 0
	mappedElement.Clicked:Connect(function()
		mappedClicks += 1
	end)
	local insetMouse = {
		UserInputType = "MouseButton1",
		Position = Vector2.new(120, 70),
	}
	mappedInput.InputBegan:Fire(insetMouse, true)
	mappedInput.InputEnded:Fire(insetMouse, true)
	assert(mappedClicks == 0)
	mappedInput.InputBegan:Fire(insetMouse, false)
	mappedInput.InputEnded:Fire(insetMouse, true)
	assert(mappedClicks == 1)
	mappedCanvas:destroy()

	local allowedFake = FakeDrawing.new()
	local allowedInput = newInputService()
	local allowedCanvas = Limn.new({
		Drawing = allowedFake.library,
		Vector2 = Vector2,
		Input = {
			Processed = "allow",
		},
	}):createCanvas()
	allowedCanvas:bindInput(allowedInput)
	local allowedElement = allowedCanvas:create("Square", {
		Position = Vector2.new(0, 0),
		Size = Vector2.new(40, 40),
		Visible = true,
	}, { interactive = true })
	local allowedClicks = 0
	allowedElement.Clicked:Connect(function()
		allowedClicks += 1
	end)
	local processedMouse = {
		UserInputType = "MouseButton1",
		Position = Vector2.new(20, 20),
	}
	allowedInput.InputBegan:Fire(processedMouse, true)
	allowedInput.InputEnded:Fire(processedMouse, true)
	assert(allowedClicks == 1)
	allowedCanvas:destroy()

	local captureFake = FakeDrawing.new()
	local capturePaint = newSignal()
	local captureImmediate = {
		GetPaint = function(zIndex: number)
			assert(zIndex == 8)
			return capturePaint
		end,
	}
	local captureCanvas = Limn.new({
		Drawing = captureFake.library,
		DrawingImmediate = captureImmediate,
	}):createCanvas()
	local captureOwner = captureCanvas:create("Square", {
		Position = Vector2.new(0, 0),
		Size = Vector2.new(100, 100),
		Visible = true,
	}, { interactive = true })
	local paintedPositions = {}
	captureCanvas:paintCaptured(captureOwner, 8, function(painter, event)
		assert(painter == captureImmediate)
		table.insert(paintedPositions, event.position)
	end)

	capturePaint:Fire()
	assert(#paintedPositions == 0)
	captureCanvas:dispatchPointer({
		phase = "down",
		position = Vector2.new(10, 10),
		pointerId = "mouse",
		processed = false,
	})
	capturePaint:Fire()
	assert(paintedPositions[1] == Vector2.new(10, 10))
	captureCanvas:dispatchPointer({
		phase = "move",
		position = Vector2.new(20, 20),
		pointerId = "mouse",
		processed = false,
	})
	captureCanvas:dispatchPointer({
		phase = "move",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = false,
	})
	capturePaint:Fire()
	assert(#paintedPositions == 2)
	assert(paintedPositions[2] == Vector2.new(30, 30))
	captureCanvas:dispatchPointer({
		phase = "up",
		position = Vector2.new(30, 30),
		pointerId = "mouse",
		processed = false,
	})
	capturePaint:Fire()
	assert(#paintedPositions == 2)
	captureCanvas:dispatchPointer({
		phase = "down",
		position = Vector2.new(10, 10),
		pointerId = "mouse",
		processed = false,
	})
	captureOwner:destroy()
	capturePaint:Fire()
	assert(#paintedPositions == 2)
	captureCanvas:destroy()
end
