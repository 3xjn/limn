--!strict

local ElementModule = require("./Element")
local InputRouterModule = require("./InputRouter")

type Element = ElementModule.Element
type Properties = ElementModule.Properties
type PointerEvent = InputRouterModule.PointerEvent
type Point = {
	X: number,
	Y: number,
}
type MapPosition = (position: Point, input: any) -> Point
type CreatePrimitive = (kind: string) -> any

export type CreateOptions = {
	interactive: boolean?,
}

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type InputSignal = {
	Connect: (self: InputSignal, callback: (any, boolean) -> ()) -> Connection,
}

export type InputService = {
	InputBegan: InputSignal,
	InputChanged: InputSignal,
	InputEnded: InputSignal,
}

export type Canvas = {
	create: (
		self: Canvas,
		kind: string,
		properties: Properties?,
		options: CreateOptions?
	) -> Element,
	getElements: (self: Canvas) -> { Element },
	dispatchPointer: (self: Canvas, event: PointerEvent) -> (),
	focus: (self: Canvas, element: Element?) -> (),
	getFocusedElement: (self: Canvas) -> Element?,
	bindInput: (self: Canvas, inputService: InputService, vector2: any?) -> Connection,
	paint: (self: Canvas, zIndex: number, callback: (any) -> ()) -> Connection,
	paintCaptured: (
		self: Canvas,
		element: Element,
		zIndex: number,
		callback: (any, PointerEvent) -> ()
	) -> Connection,
	clear: (self: Canvas) -> (),
	destroy: (self: Canvas) -> (),
}

type DrawingImmediate = {
	GetPaint: (zIndex: number) -> any,
}

type PrivateCanvas = Canvas & {
	_createPrimitive: CreatePrimitive,
	_immediate: DrawingImmediate?,
	_vector2: any?,
	_mapPosition: MapPosition?,
	_acceptProcessed: boolean,
	_elements: { Element },
	_focused: Element?,
	_dispatchKey: (self: Canvas, input: any, processed: boolean) -> (),
	_sequence: number,
	_router: InputRouterModule.InputRouter,
	_connections: { Connection },
	_destroyed: boolean,
}

local Canvas = {}
Canvas.__index = Canvas

local function elementZIndex(element: Element): number
	return element:get("ZIndex") or 0
end

function Canvas.new(
	createPrimitive: CreatePrimitive,
	immediate: DrawingImmediate?,
	vector2: any?,
	acceptProcessed: boolean?,
	mapPosition: MapPosition?
): Canvas
	local self = setmetatable({
		_createPrimitive = createPrimitive,
		_immediate = immediate,
		_vector2 = vector2,
		_mapPosition = mapPosition,
		_acceptProcessed = acceptProcessed == true,
		_elements = {},
		_focused = nil,
		_sequence = 0,
		_connections = {},
		_destroyed = false,
	}, Canvas) :: any

	self._router = InputRouterModule.new(function(event: PointerEvent): Element?
		local target: Element? = nil
		local targetZIndex = -math.huge
		local targetSequence = -math.huge

		for _, element in self._elements do
			if element:isInteractive() and element:contains(event.position) then
				local zIndex = elementZIndex(element)
				local sequence = (element :: any)._sequence
				if
					zIndex > targetZIndex or (zIndex == targetZIndex and sequence > targetSequence)
				then
					target = element
					targetZIndex = zIndex
					targetSequence = sequence
				end
			end
		end
		return target
	end, acceptProcessed)

	return self
end

function Canvas:create(kind: string, properties: Properties?, options: CreateOptions?): Element
	local canvas = self :: PrivateCanvas
	assert(not canvas._destroyed, "cannot create on a destroyed canvas")

	canvas._sequence += 1
	local object = canvas._createPrimitive(kind)
	local element: Element
	element = ElementModule.new(
		kind,
		object,
		canvas._sequence,
		options ~= nil and options.interactive == true,
		function(changed: Element, interactive: boolean)
			if not interactive then
				canvas._router:releaseElement(changed)
			end
		end,
		function()
			if canvas._focused == element then
				canvas:focus(nil)
			end
			canvas._router:releaseElement(element)
			local index = table.find(canvas._elements, element)
			if index then
				table.remove(canvas._elements, index)
			end
		end
	)
	table.insert(canvas._elements, element)
	element.PointerDown:Connect(function()
		if element:isFocusable() then
			canvas:focus(element)
		end
	end)

	if properties then
		element:patch(properties)
	end
	return element
end

function Canvas:getElements(): { Element }
	return table.clone((self :: PrivateCanvas)._elements)
end

function Canvas:dispatchPointer(event: PointerEvent)
	(self :: PrivateCanvas)._router:dispatch(event)
end

function Canvas:focus(element: Element?)
	local canvas = self :: PrivateCanvas
	if canvas._destroyed and element then
		return
	end
	if element then
		assert(table.find(canvas._elements, element), "focus element must belong to this canvas")
		assert(element:isFocusable(), "focus element must be alive and focusable")
	end

	local previous = canvas._focused
	if previous == element then
		return
	end
	canvas._focused = element
	if previous then
		previous.FocusLost:Fire()
	end
	if element then
		element.Focused:Fire()
	end
end

function Canvas:getFocusedElement(): Element?
	local canvas = self :: PrivateCanvas
	local focused = canvas._focused
	if focused and (not focused:isAlive() or not focused:isFocusable()) then
		canvas:focus(nil)
		return nil
	end
	return focused
end

local function normalizedKey(input: any): string?
	local keyCode = input.KeyCode
	if keyCode == nil then
		return nil
	end
	local name = keyCode.Name
	if type(name) == "string" and name ~= "Unknown" then
		return name
	end
	local text = tostring(keyCode)
	local lastDot = string.match(text, ".*()%.%")
	local fallback = if lastDot then string.sub(text, lastDot + 1) else text
	if fallback == "" or fallback == "Unknown" then
		return nil
	end
	return fallback
end

function Canvas:_dispatchKey(input: any, processed: boolean)
	local canvas = self :: PrivateCanvas
	if canvas._destroyed or (processed and not canvas._acceptProcessed) then
		return
	end
	local focused = canvas:getFocusedElement()
	local key = normalizedKey(input)
	if focused and key then
		focused.KeyDown:Fire(input, key)
	end
end

local function inputPosition(input: any, vector2: any, mapPosition: MapPosition?): Point
	local position = vector2.new(input.Position.X, input.Position.Y)
	if mapPosition then
		return mapPosition(position, input)
	end
	return position
end

local function pointerId(input: any): string
	if tostring(input.UserInputType):find("Touch", 1, true) then
		return tostring(input)
	end
	return "mouse"
end

function Canvas:bindInput(inputService: InputService, vector2: any?): Connection
	local canvas = self :: PrivateCanvas
	assert(not canvas._destroyed, "cannot bind input on a destroyed canvas")
	local vector2Library = vector2 or canvas._vector2
	assert(
		vector2Library,
		"bindInput requires Vector2 in Limn.new options or as its second argument"
	)

	local connections = {
		inputService.InputBegan:Connect(function(input: any, processed: boolean)
			local kind = tostring(input.UserInputType)
			if kind:find("MouseButton1", 1, true) or kind:find("Touch", 1, true) then
				canvas:dispatchPointer({
					phase = "down",
					position = inputPosition(input, vector2Library, canvas._mapPosition),
					pointerId = pointerId(input),
					processed = processed,
				})
			elseif kind:find("Keyboard", 1, true) then
				canvas:_dispatchKey(input, processed)
			end
		end),
		inputService.InputChanged:Connect(function(input: any, processed: boolean)
			local kind = tostring(input.UserInputType)
			if kind:find("MouseMovement", 1, true) or kind:find("Touch", 1, true) then
				canvas:dispatchPointer({
					phase = "move",
					position = inputPosition(input, vector2Library, canvas._mapPosition),
					pointerId = pointerId(input),
					processed = processed,
				})
			end
		end),
		inputService.InputEnded:Connect(function(input: any, processed: boolean)
			local kind = tostring(input.UserInputType)
			if kind:find("MouseButton1", 1, true) or kind:find("Touch", 1, true) then
				canvas:dispatchPointer({
					phase = "up",
					position = inputPosition(input, vector2Library, canvas._mapPosition),
					pointerId = pointerId(input),
					processed = processed,
				})
			end
		end),
	}

	local composite = {
		Connected = true,
	} :: any
	function composite:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		for _, connection in self._connections do
			connection:Disconnect()
		end
	end
	composite._connections = connections
	table.insert(canvas._connections, composite)
	return composite
end

function Canvas:paint(zIndex: number, callback: (any) -> ()): Connection
	local canvas = self :: PrivateCanvas
	assert(not canvas._destroyed, "cannot paint on a destroyed canvas")
	assert(canvas._immediate, "DrawingImmediate is unavailable")

	local connection = canvas._immediate.GetPaint(zIndex):Connect(function()
		callback(canvas._immediate)
	end)
	table.insert(canvas._connections, connection)
	return connection
end

function Canvas:paintCaptured(
	element: Element,
	zIndex: number,
	callback: (any, PointerEvent) -> ()
): Connection
	local canvas = self :: PrivateCanvas
	assert(not canvas._destroyed, "cannot paint on a destroyed canvas")
	assert(canvas._immediate, "DrawingImmediate is unavailable")
	assert(
		table.find(canvas._elements, element),
		"paintCaptured element must belong to this canvas"
	)

	local activeEvents: { [string]: PointerEvent } = {}
	local connections = {
		element.PointerDown:Connect(function(event: PointerEvent)
			activeEvents[event.pointerId] = event
		end),
		element.Dragged:Connect(function(event: PointerEvent)
			activeEvents[event.pointerId] = event
		end),
		element.PointerUp:Connect(function(event: PointerEvent)
			activeEvents[event.pointerId] = nil
		end),
		canvas._immediate.GetPaint(zIndex):Connect(function()
			if not element:isAlive() then
				table.clear(activeEvents)
				return
			end
			for _, event in activeEvents do
				callback(canvas._immediate, event)
			end
		end),
	}

	local composite = {
		Connected = true,
	} :: any
	function composite:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		table.clear(activeEvents)
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	table.insert(canvas._connections, composite)
	return composite
end

function Canvas:clear()
	local canvas = self :: PrivateCanvas
	local elements = table.clone(canvas._elements)
	for _, element in elements do
		element:destroy()
	end
end

function Canvas:destroy()
	local canvas = self :: PrivateCanvas
	if canvas._destroyed then
		return
	end
	canvas._destroyed = true
	canvas:clear()
	canvas._router:destroy()
	for _, connection in canvas._connections do
		connection:Disconnect()
	end
	table.clear(canvas._connections)
end

return Canvas
