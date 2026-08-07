local Limn = loadfile("limn/dist/Limn.lua")()

local runtime = Limn.new({
	Drawing = Drawing,
	Vector2 = Vector2,
	Input = {
		Processed = "ignore",
	},
})
local canvas = runtime:createCanvas()
canvas:bindInput(game:GetService("UserInputService"))

local style = {
	Frame = {
		Color = Color3.fromRGB(34, 38, 48),
		Filled = true,
		Visible = true,
	},
	Option = {
		Color = Color3.fromRGB(54, 60, 76),
		Filled = true,
		Visible = true,
	},
	Selected = { Color = Color3.fromRGB(78, 126, 214) },
	SelectedLabel = { Color = Color3.fromRGB(255, 255, 255) },
	Focused = { Transparency = 0.85 },
	Listening = { Color = Color3.fromRGB(224, 168, 73) },
	Disabled = { Transparency = 0.35 },
	Label = {
		Color = Color3.fromRGB(240, 242, 248),
		Size = 16,
		Visible = true,
	},
	Value = {
		Color = Color3.fromRGB(240, 242, 248),
		Size = 16,
		Visible = true,
	},
}

local quality = runtime:createSegmentedControl(canvas, {
	Position = Vector2.new(32, 32),
	Size = Vector2.new(216, 28),
	ZIndex = 10,
	Options = {
		{ Value = "low", Label = "Low" },
		{ Value = "medium", Label = "Medium" },
		{ Value = "high", Label = "High" },
	},
	Value = "medium",
	Style = style,
})

quality.Changed:Connect(function(value)
	print("Quality:", value)
end)

local shortcut = runtime:createKeybindControl(canvas, {
	Position = Vector2.new(32, 76),
	Size = Vector2.new(216, 28),
	ZIndex = 10,
	Label = "Shortcut",
	Value = "RightShift",
	Style = style,
	Layout = {
		LabelPosition = Vector2.new(40, 82),
		ValuePosition = Vector2.new(150, 82),
	},
})

shortcut.Changed:Connect(function(value)
	print("Shortcut:", value or "Unbound")
end)

-- Call quality:destroy(), shortcut:destroy(), and canvas:destroy() when the overlay unloads.
