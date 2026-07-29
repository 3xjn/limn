local Limn = loadfile("limn/dist/Limn.lua")()

local canvas = Limn.new({
	Drawing = Drawing,
	DrawingImmediate = DrawingImmediate,
	Vector2 = Vector2,
}):createCanvas()

canvas:create("Square", {
	Position = Vector2.new(24, 24),
	Size = Vector2.new(260, 120),
	Color = Color3.fromRGB(18, 20, 26),
	Filled = true,
	Visible = true,
	ZIndex = 1,
})

canvas:create("Text", {
	Position = Vector2.new(40, 40),
	Text = "Limn",
	Size = 22,
	Color = Color3.fromRGB(240, 242, 248),
	Outline = true,
	Visible = true,
	ZIndex = 2,
})

canvas:paint(0, function(painter)
	painter.Line(Vector2.new(24, 156), Vector2.new(284, 156), Color3.fromRGB(100, 160, 255), 1, 2)
end)

-- Keep `canvas` and call canvas:destroy() when the overlay is unloaded.
