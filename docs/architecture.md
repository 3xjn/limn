# Architecture

## The actual platform boundary

Volt draws persistent objects above the game viewport and can also paint transient primitives from
a render-frame callback. Those objects are renderer-owned values, not entries in Roblox's
`PlayerGui`, `CoreGui`, or hidden UI container.

That distinction controls the design:

```text
Roblox input events
        |
        v
screen-coordinate normalization
        |
        v
Limn hit testing + pointer capture
        |
        v
interactive retained elements

Volt Drawing ----------------------> pixels above the viewport
Volt DrawingImmediate -------------> transient pixels for this frame
Roblox GuiObjects -----------------> separate UI tree and event system
```

A drawing has no `InputBegan`, `Activated`, focus, selection, layout, clipping, or accessibility
behavior. Limn can emulate the parts that are meaningful for a canvas, but it should not pretend
that the result is a `GuiObject`.

## Retained versus immediate mode

Use retained elements when identity matters:

- a panel that is updated occasionally;
- a draggable handle;
- text whose bounds are used for hit testing;
- a selection that owns event subscriptions;
- anything with a lifecycle longer than one frame.

Use `canvas:paint()` when the current frame is the state:

- player/world projections;
- graphs and debug guides;
- frequently changing line batches;
- visualizations that are cheaply recomputed;
- visuals with no per-object interaction.

Immediate mode is a first-class Volt capability and should stay visible. Wrapping every immediate
primitive behind another one-to-one method would add names without adding behavior, so the paint
callback receives the native library.

Volt's immediate primitives are transient and may only be emitted from a `GetPaint()` render
callback. They are not setters for persistent `Drawing` objects. `canvas:paintCaptured()` therefore
keeps only the latest pointer event for an active capture and supplies it to that render callback;
it does not call `DrawingImmediate` from input dispatch or duplicate the consumer's stored value.

## Input flow

`Canvas:bindInput()` adapts `UserInputService` into four pointer phases:

1. `move` updates hover and sends drag motion to the captured element.
2. `down` selects the highest `ZIndex`; later creation wins ties.
3. `up` releases capture and emits `Clicked` only for a same-target release.
4. `cancel` releases capture without clicking.

The router supports independent pointer IDs so touch can be expanded without changing the element
contract. Processed Roblox input does not begin new interactions. Releases still reach an existing
capture so a consumed mouse-up cannot leave a drag stuck forever. Consumers that intentionally
share processed input can set `Input.Processed = "allow"` on the runtime.

## Coordinate spaces and Roblox UI

Volt's documented drawing coordinates and `UserInputService:GetMouseLocation()` are screen-pixel
coordinates. Roblox `ScreenGui` content may use a safe-area or top-bar inset. `GuiService:GetGuiInset`
returns the offset that applies to inset-respecting `ScreenGui`s.

Limn's base coordinate system is the full screen:

- World projections from `Camera:WorldToViewportPoint` can be used directly when they match the
  drawing viewport.
- Raw pointer locations can be compared directly to drawings.
- To align with an inset-respecting `ScreenGui`, add or subtract the GUI inset exactly once at the
  adapter boundary.

`Input.MapPosition` is that adapter boundary for pointer hit testing. It receives a normalized
screen position and returns the point used by the canvas. Limn does not silently guess from a
value's shape or apply `GuiService:GetGuiInset()` automatically.

## Why input remains optional

Most drawing use cases are visual overlays. Globally subscribing to input for every canvas would
create hidden work and surprising interference. Limn therefore requires two explicit choices:

- call `canvas:bindInput(...)`;
- mark a retained element `{ interactive = true }` or call `setInteractive(true)`.

This keeps the core useful for pure visuals while allowing a real interaction model when needed.

## What the first scaffold deliberately does not do

- **No global hooks.** The previous project hooked `TweenService.Create`; Limn owns only its own
  objects and connections.
- **No silent property failures.** Native Volt errors are allowed to identify an invalid property.
- **No automatic `UDim2` conversion.** Responsive units require an explicit viewport and inset
  policy, not a one-time camera-size multiplication.
- **No tween facade yet.** A correct scheduler needs cancellation, ownership, easing, and
  per-frame batching.
- **No application widgets in core.** The optional generic controls layer owns only retained
  segmented/keybind visuals, focus, and state; consumers own themes, labels, persistence, and
  application behavior.
- **No simulated input or game interaction.** Volt's input simulation and instance-event APIs are
  outside this library's presentation boundary.

## Module ownership

| Module | Owns |
| --- | --- |
| `Limn` | Runtime dependency injection and canvas creation |
| `Canvas` | Drawing ownership, connection cleanup, Z-order targeting |
| `Element` | One retained drawing and its interaction signals |
| `Geometry` | Pure hit-testing predicates |
| `InputRouter` | Hover, capture, drag, release, and click semantics |
| `Controls` | Generic retained segmented and keybind controls built from canvas elements |
| `Signal` | Local event subscription lifecycle |

`scripts/build.luau` bundles these source modules into `dist/Limn.lua` because Volt workspace
scripts load files, while the development source benefits from small modules and isolated tests.
