--!strict

local CanvasModule = require("./Canvas")
local Controls = require("./Controls")

export type ProcessedInputPolicy = "ignore" | "allow"

export type Point = {
	X: number,
	Y: number,
}

export type InputOptions = {
	Processed: ProcessedInputPolicy?,
	MapPosition: ((position: Point, input: any) -> Point)?,
}

export type Options = {
	Drawing: {
		new: (kind: string) -> any,
	},
	DrawingImmediate: {
		GetPaint: (zIndex: number) -> any,
	}?,
	Vector2: any?,
	SupportsPrimitive: ((kind: string) -> boolean)?,
	Input: InputOptions?,
}

export type Limn = {
	supportsPrimitive: (self: Limn, kind: string) -> boolean,
	createCanvas: (self: Limn) -> CanvasModule.Canvas,
	createSegmentedControl: (self: Limn, canvas: CanvasModule.Canvas, options: any) -> any,
	createKeybindControl: (self: Limn, canvas: CanvasModule.Canvas, options: any) -> any,
}

type PrivateLimn = Limn & {
	_createPrimitive: (self: PrivateLimn, kind: string) -> any,
	_drawing: {
		new: (kind: string) -> any,
	},
	_immediate: {
		GetPaint: (zIndex: number) -> any,
	}?,
	_vector2: any?,
	_supportsPrimitive: ((kind: string) -> boolean)?,
	_primitiveSupport: { [string]: boolean },
	_acceptProcessed: boolean,
	_mapPosition: ((position: Point, input: any) -> Point)?,
}

local Limn = {}
Limn.__index = Limn

local function removeProbe(object: any): boolean
	local remove = object.Remove
	if type(remove) == "function" then
		return pcall(remove, object)
	end
	local destroy = object.Destroy
	if type(destroy) == "function" then
		return pcall(destroy, object)
	end
	return false
end

function Limn.new(options: Options): Limn
	assert(options.Drawing, "Limn requires the Volt Drawing library")
	local inputOptions = options.Input
	local processed = if inputOptions then inputOptions.Processed else nil
	assert(
		processed == nil or processed == "ignore" or processed == "allow",
		'Input.Processed must be "ignore" or "allow"'
	)
	return setmetatable({
		_drawing = options.Drawing,
		_immediate = options.DrawingImmediate,
		_vector2 = options.Vector2,
		_supportsPrimitive = options.SupportsPrimitive,
		_primitiveSupport = {},
		_acceptProcessed = processed == "allow",
		_mapPosition = if inputOptions then inputOptions.MapPosition else nil,
	}, Limn) :: any
end

function Limn:supportsPrimitive(kind: string): boolean
	local runtime = self :: PrivateLimn
	local cached = runtime._primitiveSupport[kind]
	if cached ~= nil then
		return cached
	end

	local supports = runtime._supportsPrimitive
	local supported: boolean
	if supports then
		supported = supports(kind) == true
	else
		local ok, object = pcall(runtime._drawing.new, kind)
		supported = ok and object ~= nil and removeProbe(object)
	end
	runtime._primitiveSupport[kind] = supported
	return supported
end

function Limn:_createPrimitive(kind: string): any
	local runtime = self :: PrivateLimn
	local cached = runtime._primitiveSupport[kind]
	if
		cached == false
		or (cached == nil and runtime._supportsPrimitive and not runtime:supportsPrimitive(kind))
	then
		error(string.format("unsupported drawing kind %q", kind), 2)
	end

	local ok, object = pcall(runtime._drawing.new, kind)
	if not ok or object == nil then
		runtime._primitiveSupport[kind] = false
		error(string.format("unsupported drawing kind %q", kind), 2)
	end
	runtime._primitiveSupport[kind] = true
	return object
end

function Limn:createCanvas(): CanvasModule.Canvas
	local runtime = self :: PrivateLimn
	return CanvasModule.new(function(kind: string): any
		return runtime:_createPrimitive(kind)
	end, runtime._immediate, runtime._vector2, runtime._acceptProcessed, runtime._mapPosition)
end

function Limn:createSegmentedControl(canvas: CanvasModule.Canvas, options: any): any
	return Controls.createSegmented(canvas, options, (self :: PrivateLimn)._vector2)
end

function Limn:createKeybindControl(canvas: CanvasModule.Canvas, options: any): any
	return Controls.createKeybind(canvas, options, (self :: PrivateLimn)._vector2)
end

return Limn
