--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Destroy: (self: Signal) -> (),
}

type PrivateSignal = Signal & {
	_nextId: number,
	_listeners: { [number]: (...any) -> () },
	_destroyed: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return setmetatable({
		_nextId = 0,
		_listeners = {},
		_destroyed = false,
	}, Signal) :: any
end

function Signal:Connect(callback: (...any) -> ()): Connection
	local self = self :: PrivateSignal
	assert(not self._destroyed, "cannot connect to a destroyed signal")

	self._nextId += 1
	local id = self._nextId
	self._listeners[id] = callback

	local connection = {
		Connected = true,
	} :: any

	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		self._signal._listeners[self._id] = nil
	end

	connection._signal = self
	connection._id = id
	return connection
end

function Signal:Once(callback: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	local self = self :: PrivateSignal
	if self._destroyed then
		return
	end

	local snapshot = table.clone(self._listeners)
	for id, callback in snapshot do
		if self._listeners[id] == callback then
			callback(...)
		end
	end
end

function Signal:Destroy()
	local self = self :: PrivateSignal
	if self._destroyed then
		return
	end
	self._destroyed = true
	table.clear(self._listeners)
end

return Signal
