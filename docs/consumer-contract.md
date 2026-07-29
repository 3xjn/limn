# Consumer contract

Limn publishes one loadable artifact:

```luau
local Limn = loadfile("limn/dist/Limn.lua")()
```

Universal Hub and Hydroxide each create their own runtime and canvas. Limn does not own panels,
controls, themes, targeting logic, or game-specific drawings.

## Runtime

```luau
local runtime = Limn.new({
	Drawing = Drawing,
	DrawingImmediate = DrawingImmediate, -- optional
	Vector2 = Vector2, -- required only by bindInput()
	SupportsPrimitive = supportsPrimitive, -- optional
	Input = { -- optional
		Processed = "ignore", -- "ignore" by default, or "allow"
		MapPosition = mapPosition, -- optional
	},
})
```

The consumer-facing runtime has two methods:

```luau
runtime:supportsPrimitive(kind: string): boolean
runtime:createCanvas(): Canvas
```

`supportsPrimitive()` caches its result. Without `SupportsPrimitive`, Limn detects availability by
calling `Drawing.new(kind)` and immediately removing a successful probe. Inject
`SupportsPrimitive` when the host already has a side-effect-free capability query.

## Input and coordinates

Call `canvas:bindInput(UserInputService)` only for an interactive overlay. Processed Roblox input
does not begin hover, press, or click behavior under the default `"ignore"` policy. A release still
reaches a pointer already captured by Limn so a drag cannot remain stuck. Use `"allow"` only when
the consumer intentionally shares processed input.

Input positions are screen pixels by default. `Input.MapPosition` receives the normalized screen
position and original Roblox input object and returns the point used for hit testing.

For retained positions expressed in an inset-respecting `ScreenGui` coordinate space:

```luau
local GuiService = game:GetService("GuiService")

local function screenToGui(screenPosition)
	local topLeftInset = select(1, GuiService:GetGuiInset())
	return screenPosition - topLeftInset
end

local runtime = Limn.new({
	Drawing = Drawing,
	Vector2 = Vector2,
	Input = {
		Processed = "ignore",
		MapPosition = screenToGui,
	},
})
```

Do not install this mapper for drawings already positioned in full-screen coordinates. Limn never
guesses a coordinate space or applies a GUI inset automatically.

## Active capture feedback

`DrawingImmediate` is a transient render-frame API. Its primitive functions are called from
`GetPaint()` callbacks and do not mutate retained `Drawing` objects. Limn exposes this opt-in bridge:

```luau
canvas:paintCaptured(
	captureElement: Element,
	zIndex: number,
	callback: (DrawingImmediate, PointerEvent) -> ()
): Connection
```

For a slider, register the hit target or thumb that owns pointer capture:

```luau
local activePaint = canvas:paintCaptured(sliderHit, sliderZIndex + 1, function(painter, event)
	drawActiveThumbAndFill(painter, event.position)
end)
```

The callback:

- does not run before `captureElement` receives pointer-down;
- receives the latest down or move event for each captured pointer on every paint frame;
- stops before paints after pointer-up or cancel;
- stops if the capture element is destroyed or the returned connection is disconnected;
- is disconnected automatically when the canvas is destroyed.

Limn stores only ephemeral latest pointer events for the active capture. It does not copy the
consumer's slider/toggle value or persist settings. Keep existing movement updates nonpersistent
and persist once from `PointerUp`. Normal retained drawing remains the default for the whole canvas.
If retained thumb/fill primitives would show underneath the transient replacement, hide only those
visuals during capture, make the consumer's normal render/store patches preserve that visual-only
mask, and restore them on pointer-up. The mask is presentation lifecycle state, not a second control
value.

## Canvas ownership

The retained consumer surface remains:

```luau
local canvas = runtime:createCanvas()
local element = canvas:create(kind, properties, {
	interactive = true,
})

element:set(property, value)
element:patch(properties)
element:destroy()

canvas:paint(zIndex, callback) -- requires DrawingImmediate
canvas:paintCaptured(element, zIndex, callback) -- optional active-capture feedback
canvas:bindInput(UserInputService) -- requires Vector2
canvas:clear()
canvas:destroy()
```

Keep one canvas for each independently reloadable overlay. Call `canvas:destroy()` before replacing
that overlay; destruction removes retained drawings and disconnects input and paint callbacks.
