<h1 align="center">Limn</h1>

<p align="center"><strong>A small drawing toolkit for Roblox overlays running in Volt.</strong></p>

<p align="center">
  <a href="examples/basic.luau">Basic example →</a>
  ·
  <a href="examples/interactive.luau">Interactive example →</a>
  ·
  <a href="examples/controls.luau">Controls example →</a>
  ·
  <a href="docs/consumer-contract.md">Consumer contract →</a>
  ·
  <a href="docs/architecture.md">Architecture →</a>
</p>

Create persistent shapes, draw per-frame visuals, add hover, click, and drag behavior when you need
it, then tear down the whole overlay through one canvas. Limn works with Volt's native drawing APIs,
so drawings and their properties stay familiar.

> [!NOTE]
> Limn manages Volt drawings; it does not create Roblox `GuiObject`s or simulate input.

## ✨ What you get

| Capability | What it gives you |
| --- | --- |
| Retained drawings | Create and update lines, circles, squares, triangles, text, images, and quads. |
| Per-frame drawing | Draw temporary guides, graphs, or overlays without creating retained objects. |
| Opt-in interaction | Add hover, press, click, and drag signals only where you need them. |
| Generic controls | Compose segmented selection and keybinding controls from retained drawings. |
| Canvas cleanup | Remove owned drawings and disconnect input or paint callbacks with one call. |

---

## 📦 Quick start

Build the single-file Volt artifact:

```sh
lune run scripts/build.luau
```

Create a canvas and draw a panel:

```luau
local Limn = loadfile("limn/dist/Limn.lua")()

local canvas = Limn.new({
	Drawing = Drawing,
}):createCanvas()

local panel = canvas:create("Square", {
	Position = Vector2.new(24, 24),
	Size = Vector2.new(240, 120),
	Color = Color3.fromRGB(20, 22, 28),
	Filled = true,
	Visible = true,
})

panel:set("Color", Color3.fromRGB(45, 90, 160))

-- Removes the panel and every other object owned by this canvas.
canvas:destroy()
```

`dist/Limn.lua` is the shared runtime artifact. A consumer loads it once, creates its own runtime
and canvas, and destroys that canvas when its overlay unloads or reloads.

Pass `DrawingImmediate` to draw every frame. Pass `Vector2` to use `bindInput()`.

### Consumer contract

The public runtime surface is intentionally small:

| Method | Use |
| --- | --- |
| `runtime:supportsPrimitive(kind)` | Detect and cache whether the injected backend can create a primitive. |
| `runtime:createCanvas()` | Create an independently owned drawing and input lifecycle. |
| `runtime:createSegmentedControl(canvas, options)` | Create a retained segmented-selection control. |
| `runtime:createKeybindControl(canvas, options)` | Create a retained keyboard-rebinding control. |

Capability detection probes `Drawing.new(kind)` and immediately removes the probe. A host with a
side-effect-free capability API can inject it as `SupportsPrimitive`.

```luau
local runtime = Limn.new({
	Drawing = Drawing,
	DrawingImmediate = DrawingImmediate,
	Vector2 = Vector2,
})

if runtime:supportsPrimitive("Quad") then
	local canvas = runtime:createCanvas()
	-- The consumer owns the canvas and must destroy it when finished.
end
```

See the [consumer contract](docs/consumer-contract.md) for the complete constructor options and an
inset-mapping example for Universal Hub and Hydroxide.

---

<details>
<summary><strong>API reference</strong></summary>

### Runtime

| Method | Use |
| --- | --- |
| `runtime:supportsPrimitive(kind)` | Return cached backend availability for a primitive. |
| `runtime:createCanvas()` | Create a canvas with this runtime's input and coordinate policy. |

### Canvas

| Method | Use |
| --- | --- |
| `canvas:create(kind, properties?, options?)` | Create a retained drawing owned by the canvas. |
| `canvas:paint(zIndex, callback)` | Run `callback` every frame with Volt's `DrawingImmediate` API. |
| `canvas:paintCaptured(element, zIndex, callback)` | Draw transient feedback only while `element` owns pointer capture. |
| `canvas:bindInput(UserInputService)` | Enable pointer events for interactive elements. |
| `canvas:focus(element?)` | Set or clear Limn's drawing-canvas keyboard focus. |
| `canvas:getFocusedElement()` | Return the current focusable element, if any. |
| `canvas:clear()` | Remove every retained element. |
| `canvas:destroy()` | Clear the canvas and disconnect input and paint callbacks. |

`clear()` and `destroy()` are safe to call more than once.

### Elements

```luau
element:set("Color", Color3.new(1, 0, 0))
element:patch({ Visible = true, ZIndex = 10 })
local position = element:get("Position")
local nativeDrawing = element:getObject()
element:setInteractive(true)
element:destroy()
```

### Interaction

Create an element with `{ interactive = true }`, then connect to the signals you need:

| Interaction | Signals |
| --- | --- |
| Hover | `PointerEntered`, `PointerLeft` |
| Press | `PointerDown`, `PointerUp`, `Clicked` |
| Drag | `Dragged` |
| Keyboard focus | `Focused`, `FocusLost`, `KeyDown` |

Each signal supports `Connect`, `Once`, and connection `Disconnect`.

### Active capture feedback

Volt `DrawingImmediate` emits transient primitives from a render callback; it does not mutate a
retained drawing from an input callback. `paintCaptured()` bridges the latest event for one capture
owner into that legal render callback without storing another control value:

```luau
local activePaint = canvas:paintCaptured(sliderHit, 20, function(painter, event)
	drawActiveThumbAndFill(painter, event.position)
end)
```

The callback is inactive by default, starts after `sliderHit` receives pointer-down, sees only the
latest event for each captured pointer on a paint frame, and stops after release, cancel, element
destruction, disconnect, or canvas destruction. The consumer keeps its normal nonpersistent
movement patch and persists the final value on pointer-up. If a retained thumb or fill would remain
visible under its transient replacement, hide only those retained visuals for the same capture
lifecycle, ensure normal render/store patches preserve that mask, and restore them on pointer-up.

### Input policy

Processed input is ignored by default. Set `Input.Processed = "allow"` only when an overlay is
supposed to receive input already consumed by Roblox. `Input.MapPosition` maps raw screen pixels
into the canvas coordinate space before hit testing:

```luau
local GuiService = game:GetService("GuiService")

local runtime = Limn.new({
	Drawing = Drawing,
	Vector2 = Vector2,
	Input = {
		Processed = "ignore",
		MapPosition = function(screenPosition)
			local topLeftInset = select(1, GuiService:GetGuiInset())
			return screenPosition - topLeftInset
		end,
	},
})
```

Use this mapper only when retained drawing positions are expressed in inset-relative GUI
coordinates. Screen-space drawings should keep the default identity mapping.

</details>

---

## 🛠️ Development

```sh
stylua src tests examples scripts
lune run scripts/build.luau
lune run tests/run.luau
```

The test suite uses a fake Volt drawing backend and checks the generated `dist/Limn.lua` bundle.

<details>
<summary><strong>References</strong></summary>

- [Volt Drawing API](https://docs.voltbz.net/docs/drawing)
- [Volt DrawingImmediate](https://docs.voltbz.net/docs/drawing/immediate)
- [Volt DrawFont](https://docs.voltbz.net/docs/drawing/drawfont)
- [Roblox UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService)
- [Roblox GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)

</details>
