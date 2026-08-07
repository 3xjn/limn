--!strict

local FakeDrawing = require("./support/FakeDrawing")
local Limn = require("../dist/Limn")
local roblox = require("@lune/roblox")

local Vector2 = roblox.Vector2
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
	assert(#roundedCanvas:getElements() == 67)
	assert(roundedCanvas:getElements()[6].Kind == "Triangle")
	assert(roundedCanvas:getElements()[6]:get("PointA") == Vector2.new(6, 46))
	assert(roundedCanvas:getElements()[44]:get("Color") == "selected-label")
	assertRoundedPartition(
		roundedCanvas:getElements(),
		1,
		6,
		Vector2.new(0, 40),
		Vector2.new(80, 20),
		6,
		true,
		true
	)
	assertRoundedPartition(
		roundedCanvas:getElements(),
		23,
		28,
		Vector2.new(0, 40),
		Vector2.new(40, 20),
		6,
		true,
		false
	)
	assertRoundedPartition(
		roundedCanvas:getElements(),
		46,
		51,
		Vector2.new(40, 40),
		Vector2.new(40, 20),
		6,
		false,
		true
	)
	assert(roundedCanvas:getElements()[24]:get("Size") == Vector2.new(34, 6))
	assert(roundedCanvas:getElements()[32]:get("Visible") == false)
	assert(roundedCanvas:getElements()[47]:get("Position") == Vector2.new(40, 40))
	assert(roundedCanvas:getElements()[47]:get("Size") == Vector2.new(34, 6))
	assert(roundedCanvas:getElements()[51]:get("Visible") == false)
	rounded:setValue("b")
	assert(roundedCanvas:getElements()[44]:get("Color") == "label")
	assert(roundedCanvas:getElements()[67]:get("Color") == "selected-label")
	rounded:setLayout({ Position = Vector2.new(10, 40), Size = Vector2.new(20, 8) })
	assert(roundedCanvas:getElements()[6]:get("PointA") == Vector2.new(14, 44))
	assertRoundedPartition(
		roundedCanvas:getElements(),
		1,
		6,
		Vector2.new(10, 40),
		Vector2.new(20, 8),
		4,
		true,
		true
	)
	assertRoundedPartition(
		roundedCanvas:getElements(),
		23,
		28,
		Vector2.new(10, 40),
		Vector2.new(10, 8),
		4,
		true,
		false
	)
	assertRoundedPartition(
		roundedCanvas:getElements(),
		46,
		51,
		Vector2.new(20, 40),
		Vector2.new(10, 8),
		4,
		false,
		true
	)
	rounded:setVisible(false)
	for _, element in roundedCanvas:getElements() do
		assert(element:get("Visible") == false)
	end
	rounded:setVisible(true)
	assert(roundedCanvas:getElements()[67]:get("Color") == "selected-label")
	roundedCanvas:destroy()
	for _, object in roundedFake.objects do
		assert(object.removed)
	end
end
