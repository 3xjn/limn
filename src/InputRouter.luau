--!strict

local ElementModule = require("./Element")

type Element = ElementModule.Element

export type PointerPhase = "move" | "down" | "up" | "cancel"

export type PointerEvent = {
	phase: PointerPhase,
	position: {
		X: number,
		Y: number,
	},
	pointerId: string,
	processed: boolean,
}

export type InputRouter = {
	dispatch: (self: InputRouter, event: PointerEvent) -> (),
	releaseElement: (self: InputRouter, element: Element) -> (),
	destroy: (self: InputRouter) -> (),
}

type PrivateInputRouter = InputRouter & {
	_getTarget: (event: PointerEvent) -> Element?,
	_acceptProcessed: boolean,
	_hovered: { [string]: Element },
	_captured: { [string]: Element },
	_destroyed: boolean,
}

local InputRouter = {}
InputRouter.__index = InputRouter

function InputRouter.new(
	getTarget: (PointerEvent) -> Element?,
	acceptProcessed: boolean?
): InputRouter
	return setmetatable({
		_getTarget = getTarget,
		_acceptProcessed = acceptProcessed == true,
		_hovered = {},
		_captured = {},
		_destroyed = false,
	}, InputRouter) :: any
end

local function updateHover(self: PrivateInputRouter, event: PointerEvent, target: Element?)
	local previous = self._hovered[event.pointerId]
	if previous == target then
		return
	end

	if previous and previous:isAlive() then
		previous.PointerLeft:Fire(event)
	end
	if target then
		self._hovered[event.pointerId] = target
		target.PointerEntered:Fire(event)
	else
		self._hovered[event.pointerId] = nil
	end
end

function InputRouter:dispatch(event: PointerEvent)
	local self = self :: PrivateInputRouter
	if self._destroyed then
		return
	end

	local captured: Element? = self._captured[event.pointerId]
	if captured and not captured:isAlive() then
		self._captured[event.pointerId] = nil
		captured = nil
	end

	if event.processed and not self._acceptProcessed and captured == nil then
		return
	end

	local target = self._getTarget(event)
	if event.phase == "move" then
		updateHover(self, event, target)
		if captured then
			captured.Dragged:Fire(event)
		end
	elseif event.phase == "down" then
		updateHover(self, event, target)
		if target then
			self._captured[event.pointerId] = target
			target.PointerDown:Fire(event)
		end
	elseif event.phase == "up" then
		if captured then
			captured.PointerUp:Fire(event)
			if target == captured then
				captured.Clicked:Fire(event)
			end
		end
		self._captured[event.pointerId] = nil
		updateHover(self, event, target)
	elseif event.phase == "cancel" then
		if captured then
			captured.PointerUp:Fire(event)
		end
		self._captured[event.pointerId] = nil
		updateHover(self, event, nil)
	end
end

function InputRouter:releaseElement(element: Element)
	local self = self :: PrivateInputRouter
	for pointerId, hovered in self._hovered do
		if hovered == element then
			self._hovered[pointerId] = nil
		end
	end
	for pointerId, captured in self._captured do
		if captured == element then
			self._captured[pointerId] = nil
		end
	end
end

function InputRouter:destroy()
	local self = self :: PrivateInputRouter
	if self._destroyed then
		return
	end
	self._destroyed = true
	table.clear(self._hovered)
	table.clear(self._captured)
end

return InputRouter
