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

local function countKind(elements, kind: string): number
	local count = 0
	for _, element in elements do
		if element.Kind == kind then
			count += 1
		end
	end
	return count
end

local CORNER_SECTORS = 4

local function rectanglesOverlap(first, second): boolean
	local firstPosition = first:get("Position")
	local firstSize = first:get("Size")
	local secondPosition = second:get("Position")
	local secondSize = second:get("Size")
	return math.max(firstPosition.X, secondPosition.X)
			< math.min(firstPosition.X + firstSize.X, secondPosition.X + secondSize.X)
		and math.max(firstPosition.Y, secondPosition.Y)
			< math.min(firstPosition.Y + firstSize.Y, secondPosition.Y + secondSize.Y)
end

local function assertTriangleFan(
	elements,
	firstIndex: number,
	center,
	radius: number,
	startAngle: number,
	endAngle: number
)
	local step = (endAngle - startAngle) / CORNER_SECTORS
	local previous = nil
	for offset = 0, CORNER_SECTORS - 1 do
		local triangle = elements[firstIndex + offset]
		local from = startAngle + step * offset
		local to = from + step
		assert(triangle.Kind == "Triangle")
		assert(triangle:get("PointA") == center)
		assert(
			triangle:get("PointB")
				== Vector2.new(
					center.X + math.cos(from) * radius,
					center.Y + math.sin(from) * radius
				)
		)
		assert(
			triangle:get("PointC")
				== Vector2.new(center.X + math.cos(to) * radius, center.Y + math.sin(to) * radius)
		)
		if previous then
			assert(triangle:get("PointB") == previous:get("PointC"))
		end
		previous = triangle
	end
end

local function assertRoundedPartition(
	elements,
	firstSquare: number,
	firstTriangle: number,
	position,
	size,
	radius: number,
	leftRounded: boolean,
	rightRounded: boolean
)
	for firstOffset = 0, 4 do
		for secondOffset = firstOffset + 1, 4 do
			assert(
				not rectanglesOverlap(
					elements[firstSquare + firstOffset],
					elements[firstSquare + secondOffset]
				)
			)
		end
	end
	if leftRounded then
		assertTriangleFan(
			elements,
			firstTriangle,
			Vector2.new(position.X + radius, position.Y + radius),
			radius,
			-math.pi / 2,
			-math.pi
		)
		assertTriangleFan(
			elements,
			firstTriangle + CORNER_SECTORS * 3,
			Vector2.new(position.X + radius, position.Y + size.Y - radius),
			radius,
			math.pi / 2,
			math.pi
		)
	else
		assert(elements[firstTriangle]:get("Visible") == false)
		assert(elements[firstTriangle + CORNER_SECTORS * 3]:get("Visible") == false)
	end
	if rightRounded then
		assertTriangleFan(
			elements,
			firstTriangle + CORNER_SECTORS,
			Vector2.new(position.X + size.X - radius, position.Y + radius),
			radius,
			-math.pi / 2,
			0
		)
		assertTriangleFan(
			elements,
			firstTriangle + CORNER_SECTORS * 2,
			Vector2.new(position.X + size.X - radius, position.Y + size.Y - radius),
			radius,
			0,
			math.pi / 2
		)
	else
		assert(elements[firstTriangle + CORNER_SECTORS]:get("Visible") == false)
		assert(elements[firstTriangle + CORNER_SECTORS * 2]:get("Visible") == false)
	end
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

	local zeroFake = FakeDrawing.new()
	local zeroRuntime = Limn.new({ Drawing = zeroFake.library, Vector2 = Vector2 })
	local zeroCanvas = zeroRuntime:createCanvas()
	zeroRuntime:createSegmentedControl(zeroCanvas, {
		Position = Vector2.new(0, 0),
		Size = Vector2.new(80, 20),
		Options = {
			{ Value = "a", Label = "A" },
			{ Value = "b", Label = "B" },
		},
		Value = "a",
	})
	local zeroControl = zeroRuntime:createSegmentedControl(zeroCanvas, {
		Position = Vector2.new(0, 30),
		Size = Vector2.new(80, 20),
		CornerRadius = 0,
		Options = {
			{ Value = "a", Label = "A" },
			{ Value = "b", Label = "B" },
		},
		Value = "a",
	})
	assert(#zeroCanvas:getElements() == 10)
	assert(countKind(zeroCanvas:getElements(), "Square") == 6)
	assert(countKind(zeroCanvas:getElements(), "Text") == 4)
	assert(countKind(zeroCanvas:getElements(), "Circle") == 0)
	assert(#zeroFake.objects == 10)
	assert(zeroCanvas:getElements()[1]:get("Position") == Vector2.new(0, 0))
	assert(zeroCanvas:getElements()[6]:get("Position") == Vector2.new(0, 30))
	for index = 1, 5 do
		local omitted = zeroCanvas:getElements()[index]
		local explicitZero = zeroCanvas:getElements()[index + 5]
		assert(omitted.Kind == explicitZero.Kind)
		assert(omitted:get("Visible") == explicitZero:get("Visible"))
		assert(omitted:get("ZIndex") == explicitZero:get("ZIndex"))
		if omitted.Kind == "Square" then
			assert(omitted:get("Size") == explicitZero:get("Size"))
		end
	end
	zeroControl:destroy()
	zeroCanvas:destroy()
	for _, object in zeroFake.objects do
		assert(object.removed)
	end

	local unsupportedFake = FakeDrawing.new()
	local unsupportedRuntime = Limn.new({
		Drawing = unsupportedFake.library,
		Vector2 = Vector2,
		SupportsPrimitive = function(kind: string): boolean
			return kind ~= "Triangle"
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
		string.find(tostring(unsupportedMessage), "CornerRadius requires Triangle support", 1, true)
	)
	assert(#unsupportedCanvas:getElements() == 0 and #unsupportedFake.objects == 0)

	local roundedFake = FakeDrawing.new()
	local roundedInput = newInputService()
	local roundedRuntime = Limn.new({ Drawing = roundedFake.library, Vector2 = Vector2 })
	local roundedCanvas = roundedRuntime:createCanvas()
	roundedCanvas:bindInput(roundedInput)
	local roundedChanges = 0
	local rounded = roundedRuntime:createSegmentedControl(roundedCanvas, {
		Position = Vector2.new(20, 100),
		Size = Vector2.new(80, 20),
		ZIndex = 40,
		CornerRadius = 6,
		Options = {
			{ Value = "low", Label = "Low" },
			{ Value = "high", Label = "High" },
		},
		Value = "low",
		Style = {
			Frame = { Color = "frame", Position = Vector2.new(-1, -1), Visible = false },
			Option = { Color = "option", Position = Vector2.new(-2, -2), Size = Vector2.new(1, 1) },
			Selected = { Color = "selected" },
			Hovered = { Color = "hovered" },
			Focused = { Transparency = 0.8 },
			Disabled = { Color = "disabled", Transparency = 0.4 },
			Label = { Color = "label", Position = Vector2.new(-3, -3), Visible = false },
			SelectedLabel = {
				Color = "selected-label",
				Position = Vector2.new(-4, -4),
				Visible = false,
			},
		},
	})
	rounded.Changed:Connect(function()
		roundedChanges += 1
	end)
	assert(#roundedCanvas:getElements() == 67)
	assert(countKind(roundedCanvas:getElements(), "Square") == 17)
	assert(countKind(roundedCanvas:getElements(), "Triangle") == 48)
	assert(countKind(roundedCanvas:getElements(), "Text") == 2)
	assert(roundedCanvas:getElements()[1]:get("Position") == Vector2.new(26, 106))
	assert(roundedCanvas:getElements()[1]:get("Size") == Vector2.new(68, 8))
	assert(roundedCanvas:getElements()[1]:get("ZIndex") == 40)
	assert(roundedCanvas:getElements()[1]:get("Visible") == true)
	assert(roundedCanvas:getElements()[2]:get("Position") == Vector2.new(26, 100))
	assert(roundedCanvas:getElements()[2]:get("Size") == Vector2.new(68, 6))
	assert(roundedCanvas:getElements()[6]:get("PointA") == Vector2.new(26, 106))
	assert(roundedCanvas:getElements()[22]:isInteractive())
	assert(roundedCanvas:getElements()[22]:isFocusable())
	assert(roundedCanvas:getElements()[23]:get("Position") == Vector2.new(26, 106))
	assert(roundedCanvas:getElements()[23]:get("ZIndex") == 41)
	assert(roundedCanvas:getElements()[23]:get("Visible") == true)
	assert(roundedCanvas:getElements()[24]:get("Position") == Vector2.new(26, 100))
	assert(roundedCanvas:getElements()[24]:get("Size") == Vector2.new(34, 6))
	assert(roundedCanvas:getElements()[32]:get("Visible") == false)
	assert(roundedCanvas:getElements()[47]:get("Position") == Vector2.new(60, 100))
	assert(roundedCanvas:getElements()[47]:get("Size") == Vector2.new(34, 6))
	assert(roundedCanvas:getElements()[51]:get("Visible") == false)
	assertRoundedPartition(
		roundedCanvas:getElements(),
		23,
		28,
		Vector2.new(20, 100),
		Vector2.new(40, 20),
		6,
		true,
		false
	)
	assertRoundedPartition(
		roundedCanvas:getElements(),
		46,
		51,
		Vector2.new(60, 100),
		Vector2.new(40, 20),
		6,
		false,
		true
	)
	for index, element in roundedCanvas:getElements() do
		if index == 22 or index == 45 then
			assert(element:isInteractive() and element:isFocusable())
		else
			assert(not element:isInteractive() and not element:isFocusable())
		end
	end
	assert(roundedCanvas:getElements()[44]:get("Color") == "selected-label")
	assert(roundedCanvas:getElements()[44]:get("Position") == Vector2.new(20, 100))
	assert(roundedCanvas:getElements()[44]:get("ZIndex") == 42)
	assert(roundedCanvas:getElements()[44]:get("Visible") == true)
	assert(roundedCanvas:getElements()[67]:get("Color") == "label")

	local roundedPointerDown = 0
	roundedCanvas:getElements()[22].PointerDown:Connect(function()
		roundedPointerDown += 1
	end)
	roundedCanvas:dispatchPointer(pointer("down", 20, 100, true))
	roundedCanvas:dispatchPointer(pointer("up", 20, 100, true))
	assert(roundedPointerDown == 0 and roundedCanvas:getFocusedElement() == nil)
	roundedCanvas:dispatchPointer(pointer("down", 20, 100))
	roundedCanvas:dispatchPointer(pointer("up", 20, 100))
	assert(
		roundedPointerDown == 1
			and roundedCanvas:getFocusedElement() == roundedCanvas:getElements()[22]
	)
	roundedCanvas:dispatchPointer(pointer("down", 60, 100))
	roundedCanvas:dispatchPointer(pointer("up", 60, 100))
	assert(rounded:getValue() == "high" and roundedChanges == 1)
	assert(roundedCanvas:getElements()[46]:get("Color") == "hovered")
	assert(roundedCanvas:getElements()[46]:get("Transparency") == 0.8)
	assert(roundedCanvas:getElements()[67]:get("Color") == "selected-label")
	rounded:setValue("low")
	assert(roundedChanges == 2)
	assert(roundedCanvas:getElements()[44]:get("Color") == "selected-label")
	assert(roundedCanvas:getElements()[67]:get("Color") == "label")

	rounded:setLayout({ Position = Vector2.new(10, 50), Size = Vector2.new(20, 8) })
	assert(roundedCanvas:getElements()[1]:get("Position") == Vector2.new(14, 54))
	assert(roundedCanvas:getElements()[1]:get("Size") == Vector2.new(12, 0))
	assert(roundedCanvas:getElements()[2]:get("Position") == Vector2.new(14, 50))
	assert(roundedCanvas:getElements()[2]:get("Size") == Vector2.new(12, 4))
	assert(roundedCanvas:getElements()[6]:get("PointA") == Vector2.new(14, 54))
	assert(roundedCanvas:getElements()[22]:get("Position") == Vector2.new(10, 50))
	assert(roundedCanvas:getElements()[22]:get("Size") == Vector2.new(10, 8))
	assert(roundedCanvas:getElements()[23]:get("Position") == Vector2.new(14, 54))
	assert(roundedCanvas:getElements()[28]:get("PointA") == Vector2.new(14, 54))
	assert(roundedCanvas:getElements()[44]:get("Position") == Vector2.new(10, 50))

	rounded:setDisabled(true)
	assert(roundedCanvas:getElements()[23]:get("Color") == "disabled")
	assert(roundedCanvas:getElements()[23]:get("Transparency") == 0.4)
	assert(roundedCanvas:getElements()[44]:get("Color") == "selected-label")
	rounded:setDisabled(false)
	roundedCanvas:dispatchPointer(pointer("down", 15, 54))
	assert(roundedPointerDown == 2)
	rounded:setVisible(false)
	roundedCanvas:dispatchPointer(pointer("up", 15, 54))
	assert(rounded:getValue() == "low" and roundedChanges == 2)
	assert(roundedCanvas:getFocusedElement() == nil)
	roundedCanvas:dispatchPointer(pointer("down", 15, 54))
	roundedCanvas:dispatchPointer(pointer("up", 15, 54))
	assert(roundedPointerDown == 2 and roundedCanvas:getFocusedElement() == nil)
	for _, element in roundedCanvas:getElements() do
		assert(element:get("Visible") == false)
	end
	rounded:setVisible(true)
	assert(#roundedCanvas:getElements() == 67)
	assert(roundedCanvas:getElements()[6]:get("PointA") == Vector2.new(14, 54))
	assert(roundedCanvas:getElements()[44]:get("Color") == "selected-label")
	roundedCanvas:clear()
	roundedCanvas:clear()
	rounded:destroy()
	for _, object in roundedFake.objects do
		assert(object.removed)
	end

	local seamFake = FakeDrawing.new()
	local seamRuntime = Limn.new({ Drawing = seamFake.library, Vector2 = Vector2 })
	local seamCanvas = seamRuntime:createCanvas()
	local seam = seamRuntime:createSegmentedControl(seamCanvas, {
		Position = Vector2.new(20, 20),
		Size = Vector2.new(80, 20),
		CornerRadius = 6,
		Options = { { Value = "a", Label = "A" } },
		Style = {
			Frame = { Transparency = 0.42 },
			Option = { Transparency = 0.42 },
			Selected = { Transparency = 0.42 },
		},
	})
	assert(#seamCanvas:getElements() == 44)
	assert(countKind(seamCanvas:getElements(), "Square") == 11)
	assert(countKind(seamCanvas:getElements(), "Triangle") == 32)
	assert(countKind(seamCanvas:getElements(), "Text") == 1)
	assert(seamCanvas:getElements()[22]:isInteractive())
	assert(not seamCanvas:getElements()[23]:isInteractive())
	assertRoundedPartition(
		seamCanvas:getElements(),
		1,
		6,
		Vector2.new(20, 20),
		Vector2.new(80, 20),
		6,
		true,
		true
	)
	assertRoundedPartition(
		seamCanvas:getElements(),
		23,
		28,
		Vector2.new(20, 20),
		Vector2.new(80, 20),
		6,
		true,
		true
	)
	seam:setLayout({ Position = Vector2.new(10, 50), Size = Vector2.new(20, 8) })
	assertRoundedPartition(
		seamCanvas:getElements(),
		1,
		6,
		Vector2.new(10, 50),
		Vector2.new(20, 8),
		4,
		true,
		true
	)
	assertRoundedPartition(
		seamCanvas:getElements(),
		23,
		28,
		Vector2.new(10, 50),
		Vector2.new(20, 8),
		4,
		true,
		true
	)
	seamCanvas:destroy()
	for _, object in seamFake.objects do
		assert(object.removed)
	end

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
