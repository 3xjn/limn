# Segmented Rounded Geometry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a generic `CornerRadius` option to retained segmented controls without changing their rectangular input behavior or zero-radius output.

**Architecture:** Keep the existing Square frame and segment targets. For a positive radius, render the frame and each segment state through retained horizontal/vertical Squares plus four retained Circles, clamping the radius for each rectangle. Segment hit Squares stay rectangular and interactive but visually transparent; all rounded pieces are owned, noninteractive, and refreshed through the existing state/layout/visibility lifecycle.

**Tech Stack:** Luau, Lune, Stylua, retained Volt Drawing primitives, fake Drawing test backend.

---

### Task 1: Specify failing rounded-control contracts

**Files:**
- Modify: `tests/Controls.spec.luau`
- Modify: `tests/Bundle.spec.luau`

**Step 1: Write the failing source contracts.**

Assert that omitted and zero `CornerRadius` retain the existing Square/Text count, kinds, geometry, and state behavior. Create a positive-radius control and assert its helper Circle/Square count, noninteractive ownership, radius clamp, exact initial and relaid-out geometry, rectangular segment hit/capture/focus behavior, state precedence, selected label transfer, visibility, disabled behavior, and destroy/canvas cleanup.

**Step 2: Write the unsupported-primitive and bundled contracts.**

Use `SupportsPrimitive` returning false for `Circle` to assert a clear construction error before any control primitives are created. Load `dist/Limn.lua` for an equivalent positive-radius state/layout/visibility/value contract.

**Step 3: Run the contracts before implementation.**

Run: `lune run tests/run.luau`

Expected: the new rounded-control assertions fail because `CornerRadius` is not implemented.

### Task 2: Implement private rounded retained geometry

**Files:**
- Modify: `src/Controls.luau`
- Modify: `src/Limn.luau`

**Step 1: Validate the option and Circle capability.**

Accept a nonnegative numeric `CornerRadius`; for a positive value, query Limn's existing primitive support cache and raise `segmented CornerRadius requires Circle support` before creating any control elements.

**Step 2: Add rounded visual ownership.**

Create each visual as two retained Squares and four retained Circles. Apply `Frame` or the current `Option` → `Selected` → `Hovered` → `Focused` → `Disabled` patch order to every visual piece; preserve the existing label `Label` → `SelectedLabel` flow unchanged.

**Step 3: Make geometry and lifecycle authoritative.**

Clamp radius to half the current width and height, update all helper position/size/radius/ZIndex after style patches, and apply control visibility last. Retain existing segments as rectangular focusable input targets; make their visual contribution transparent only for rounded mode. Include every helper in `owned` so existing destroy and canvas clear behavior remove them idempotently.

**Step 4: Run source contracts.**

Run: `lune run tests/run.luau`

Expected: source control contracts pass; the bundled contract remains stale until regeneration.

### Task 3: Document, exercise, and publish the generated artifact

**Files:**
- Modify: `docs/consumer-contract.md`
- Modify: `examples/controls.luau`
- Modify: `tests/manual-smoke.luau`
- Modify: `dist/Limn.lua` (generated)
- Create: untracked preview under `C:/Users/asher/.codex/visualizations/2026/08/06/019fd480-7423-7363-b29d-9c5ec68621cc/`

**Step 1: Document `CornerRadius`.**

Describe zero-radius compatibility, Circle support failure behavior, clamping, visual-only rounded geometry, and preserved rectangular focus/hit semantics. Add an unambiguous generic example.

**Step 2: Extend bundled manual smoke and make the preview.**

Exercise a rounded selection/state/layout/visibility path through `dist/Limn.lua`. Generate an SVG or PNG by serializing the actual fake retained objects produced by that scenario; show zero-radius and rounded selected/hover/disabled states without hand-drawn geometry.

**Step 3: Format and validate.**

Run: Stylua on changed Luau files, `lune run scripts/build.luau`, `lune run tests/run.luau`, `lune run tests/manual-smoke.luau`, `sha256sum dist/Limn.lua`, and `git diff --check`.

Expected: build passes, six suites pass, bundled manual smoke passes, and the generated bundle hash is recorded.

**Step 4: Commit and push the atomic feature.**

Stage only the source, generated bundle, direct tests/docs/example/plan. Leave the preview untracked unless repository convention requires it. Commit in the established imperative style and push `codex/limn-generic-controls`.
