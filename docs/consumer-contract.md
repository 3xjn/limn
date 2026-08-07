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
	Vector2 = Vector2, -- required by bindInput() and retained controls
	SupportsPrimitive = supportsPrimitive, -- optional
	Input = { -- optional
		Processed = "ignore", -- "ignore" by default, or "allow"
		MapPosition = mapPosition, -- optional
	},
})
```

The consumer-facing runtime has four methods:

```luau
runtime:supportsPrimitive(kind: string): boolean
runtime:createCanvas(): Canvas
runtime:createSegmentedControl(canvas: Canvas, options): SegmentedControl
runtime:createKeybindControl(canvas: Canvas, options): KeybindControl
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

## Focus and keyboard input

Call `element:setFocusable(true)` for a retained interactive element that should receive keyboard
input. Pointer-down on that element focuses it. The canvas exposes `focus(element?)` and
`getFocusedElement()` for programmatic focus management. Focusable elements publish `Focused`,
`FocusLost`, and `KeyDown(input, normalizedKey)` signals.

Keyboard dispatch is part of `canvas:bindInput()` and follows the same processed-input policy as
pointer dispatch: processed input is ignored unless `Input.Processed = "allow"`. Destroying an
element or its canvas releases focus before its signals are cleaned up.

## Generic retained controls

Controls require `Vector2` in `Limn.new()` and use the existing canvas and its `bindInput()`
connection; they do not install another router. They own their retained drawings and connections,
and their `destroy()` methods are idempotent. Destroying either a control or its canvas releases
focus and pointer capture safely.

```luau
local quality = runtime:createSegmentedControl(canvas, {
	Position = Vector2.new(24, 24),
	Size = Vector2.new(240, 28),
	ZIndex = 10,
	Options = {
		{ Value = "low", Label = "Low" },
		{ Value = "high", Label = "High" },
	},
	Value = "low",
	CornerRadius = 6, -- optional; zero or omitted keeps the legacy square rendering
	Style = style,
})

quality.Changed:Connect(function(value, previous, source)
	-- source is "pointer", "keyboard", or "programmatic"
end)
```

Segmented controls expose `Changed`, `StateChanged`, `getValue()`, `getState()`, `setValue(value)`,
`setDisabled(boolean)`, `setLayout(layout)`, `setVisible(boolean)`, and `destroy()`. Options are
focusable retained squares: arrow keys move focus; Enter or Space activates the focused option. The
default layout divides the supplied bounds horizontally. `setLayout` replaces geometry completely:
it requires `Position` and `Size`, and its optional `Layout(index, count, position, size)` returns
`Position`, `Size`, and optionally `LabelPosition`; omitting `Layout` restores the default.
`CornerRadius` is an optional nonnegative number. Omitted or zero keeps the exact legacy retained
Square rendering; a positive value renders the frame and segment state with owned retained Squares
and Circles, clamped to half of each current rectangle's width and height. Positive radii require
retained `Circle` support and construction fails clearly when it is unavailable. Rounded geometry is
visual only: segment hit, capture, focus, keyboard, and processed-input behavior remain rectangular
over the existing segment bounds. Rounded helpers are owned by the control and never interactive or
focusable.

```luau
local shortcut = runtime:createKeybindControl(canvas, {
	Position = Vector2.new(24, 64),
	Size = Vector2.new(240, 28),
	ZIndex = 10,
	Label = "Shortcut",
	Value = "RightShift",
	Style = style,
	Layout = {
		LabelPosition = Vector2.new(32, 70),
		ValuePosition = Vector2.new(150, 70),
	},
})
```

Keybind controls expose `Changed`, `ListeningChanged`, `StateChanged`, `getValue()`,
`getDisplayValue()`, `getState()`, `setValue(value)`, `begin()`, `cancel()`, `clear()`,
`setDisabled(boolean)`, `setLayout(layout)`, `setVisible(boolean)`, and `destroy()`. Click, Enter,
or Space begins listening. Limn stores the canonical `KeyCode.Name` and also normalizes
`Enum.KeyCode.Name` values. Escape cancels; Backspace or Delete clears. `setLayout` requires
`Position` and `Size`; its optional `Layout` supplies `LabelPosition` and `ValuePosition`, and an
omitted `Layout` restores the default.

`setVisible(false)` hides every primitive owned by a control, releases its pointer capture and
focus immediately, and prevents further pointer or keyboard input. A keybind also cancels listening
without changing its value. Showing a control again retains only persistent value and disabled state;
it does not restore focus, capture, or listening. These lifecycle operations never fire `Changed`.

Provide labels through segmented `Options[].Label` and keybind `Label`, and provide retained drawing
properties through style tables. The deterministic state overlays are `Frame`, `Option`,
`Selected`, `Hovered`, `Focused`, `Listening`, `Disabled`, `Label`, `SelectedLabel`, and `Value` as
applicable. A segmented square applies `Option` → `Selected` → `Hovered` → `Focused` → `Disabled`.
Its existing text label applies `Label` and then `SelectedLabel` only when its option is selected;
`Label` is reapplied first on every refresh, so deselection restores every property provided by
`Label`. Label selection is independent of square hover, focus, and disabled styling. Control-owned
`Position`, `ZIndex`, and `Visible` are restored after style patches, so label styles cannot override
layout or visibility. Put each property that needs resetting in the base table as well as its state
overlay.

Consumers are responsible for making selected, focused, listening, and disabled states visibly
distinct and for supplying meaningful labels. Limn supplies programmatic state and input
affordances only: its drawing primitives are not Roblox `GuiObject`s and it makes no Roblox
accessibility claim.
