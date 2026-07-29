local Limn = loadfile("limn/dist/Limn.lua")()
local GuiService = game:GetService("GuiService")

local canvas = Limn.new({
	Drawing = Drawing,
	Vector2 = Vector2,
	Input = {
		Processed = "ignore",
		MapPosition = function(screenPosition)
			local topLeftInset = select(1, GuiService:GetGuiInset())
			return screenPosition - topLeftInset
		end,
	},
}):createCanvas()

canvas:bindInput(game:GetService("UserInputService"))

local button = canvas:create("Square", {
	Position = Vector2.new(40, 40),
	Size = Vector2.new(180, 44),
	Color = Color3.fromRGB(45, 48, 58),
	Filled = true,
	Visible = true,
	ZIndex = 10,
}, {
	interactive = true,
})

button.PointerEntered:Connect(function()
	button:set("Color", Color3.fromRGB(60, 96, 160))
end)

button.PointerLeft:Connect(function()
	button:set("Color", Color3.fromRGB(45, 48, 58))
end)

button.Clicked:Connect(function()
	print("Limn button clicked")
end)

-- Keep `canvas` and call canvas:destroy() when the overlay is unloaded.
