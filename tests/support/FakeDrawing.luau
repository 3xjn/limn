--!strict

export type FakeObject = {
	Visible: boolean,
	ZIndex: number,
	Transparency: number,
	removed: boolean,
	Remove: (self: FakeObject) -> (),
	Destroy: (self: FakeObject) -> (),
	[string]: any,
}

local FakeDrawing = {}

function FakeDrawing.new()
	local objects: { FakeObject } = {}

	local library = {}
	function library.new(kind: string): FakeObject
		local object = {
			Visible = false,
			ZIndex = 0,
			Transparency = 1,
			removed = false,
			kind = kind,
		} :: any

		function object:Remove()
			self.removed = true
			self.Visible = false
		end

		object.Destroy = object.Remove
		table.insert(objects, object)
		return object
	end

	return {
		library = library,
		objects = objects,
	}
end

return FakeDrawing
