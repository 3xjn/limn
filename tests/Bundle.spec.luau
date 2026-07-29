--!strict

local FakeDrawing = require("./support/FakeDrawing")
local Limn = require("../dist/Limn")

return function()
	local fake = FakeDrawing.new()
	local runtime = Limn.new({ Drawing = fake.library })
	assert(runtime:supportsPrimitive("Square"))
	local canvas = runtime:createCanvas()
	canvas:create("Square", {
		Visible = true,
	})
	assert(#canvas:getElements() == 1)
	canvas:destroy()
	assert(fake.objects[1].removed)
	assert(fake.objects[2].removed)
end
