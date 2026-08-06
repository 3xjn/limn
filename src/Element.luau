--!strict

local Geometry = require("./Geometry")
local Signal = require("./Signal")

export type Properties = { [string]: any }

export type Element = {
	Kind: string,
	PointerEntered: Signal.Signal,
	PointerLeft: Signal.Signal,
	PointerDown: Signal.Signal,
	PointerUp: Signal.Signal,
	Clicked: Signal.Signal,
	Dragged: Signal.Signal,
	Focused: Signal.Signal,
	FocusLost: Signal.Signal,
	KeyDown: Signal.Signal,
	set: (self: Element, property: string, value: any) -> Element,
	patch: (self: Element, properties: Properties) -> Element,
	get: (self: Element, property: string) -> any,
	getObject: (self: Element) -> any,
	setInteractive: (self: Element, interactive: boolean) -> Element,
	isInteractive: (self: Element) -> boolean,
	setFocusable: (self: Element, focusable: boolean) -> Element,
	isFocusable: (self: Element) -> boolean,
	contains: (self: Element, point: Geometry.Point, padding: number?) -> boolean,
	isAlive: (self: Element) -> boolean,
	destroy: (self: Element) -> (),
}

type PrivateElement = Element & {
	_object: any,
	_sequence: number,
	_interactive: boolean,
	_onInteractiveChanged: (Element, boolean) -> (),
	_focusable: boolean,
	_alive: boolean,
	_onDestroy: (Element) -> (),
}

local Element = {}
Element.__index = Element

function Element.new(
	kind: string,
	object: any,
	sequence: number,
	interactive: boolean,
	onInteractiveChanged: (Element, boolean) -> (),
	onDestroy: (Element) -> ()
): Element
	return setmetatable({
		Kind = kind,
		PointerEntered = Signal.new(),
		PointerLeft = Signal.new(),
		PointerDown = Signal.new(),
		PointerUp = Signal.new(),
		Clicked = Signal.new(),
		Dragged = Signal.new(),
		Focused = Signal.new(),
		FocusLost = Signal.new(),
		KeyDown = Signal.new(),
		_object = object,
		_sequence = sequence,
		_interactive = interactive,
		_onInteractiveChanged = onInteractiveChanged,
		_focusable = false,
		_alive = true,
		_onDestroy = onDestroy,
	}, Element) :: any
end

function Element:set(property: string, value: any): Element
	local self = self :: PrivateElement
	assert(self._alive, "cannot update a destroyed element")
	self._object[property] = value
	return self
end

function Element:patch(properties: Properties): Element
	for property, value in properties do
		self:set(property, value)
	end
	return self
end

function Element:get(property: string): any
	local self = self :: PrivateElement
	assert(self._alive, "cannot read a destroyed element")
	return self._object[property]
end

function Element:getObject(): any
	local self = self :: PrivateElement
	assert(self._alive, "cannot access a destroyed element")
	return self._object
end

function Element:setInteractive(interactive: boolean): Element
	local self = self :: PrivateElement
	assert(self._alive, "cannot update a destroyed element")
	if self._interactive == interactive then
		return self
	end
	self._interactive = interactive
	self._onInteractiveChanged(self, interactive)
	return self
end

function Element:isInteractive(): boolean
	local self = self :: PrivateElement
	return self._alive and self._interactive
end

function Element:setFocusable(focusable: boolean): Element
	local self = self :: PrivateElement
	assert(self._alive, "cannot update a destroyed element")
	self._focusable = focusable
	return self
end

function Element:isFocusable(): boolean
	local self = self :: PrivateElement
	return self._alive and self._focusable
end

function Element:contains(point: Geometry.Point, padding: number?): boolean
	local self = self :: PrivateElement
	if not self._alive or self._object.Visible == false or self._object.Transparency == 0 then
		return false
	end
	return Geometry.contains(self.Kind, self._object, point, padding)
end

function Element:isAlive(): boolean
	return (self :: PrivateElement)._alive
end

function Element:destroy()
	local self = self :: PrivateElement
	if not self._alive then
		return
	end

	self._alive = false
	self._object:Remove()
	self._onDestroy(self)
	self.PointerEntered:Destroy()
	self.PointerLeft:Destroy()
	self.PointerDown:Destroy()
	self.PointerUp:Destroy()
	self.Clicked:Destroy()
	self.Dragged:Destroy()
	self.Focused:Destroy()
	self.FocusLost:Destroy()
	self.KeyDown:Destroy()
end

return Element
