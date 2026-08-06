# Control Layout and Visibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add compact, generic layout replacement and visibility lifecycle APIs to Limn's retained segmented and keybind controls.

**Architecture:** Keep geometry and visual ownership inside `src/Controls.luau`. Add only the Canvas primitive needed to release capture when a control becomes hidden, then update control visuals and interaction state atomically without changing values or emitting `Changed`.

**Tech Stack:** Luau, Lune, Stylua, fake Volt Drawing backend.

---

### Task 1: Specify failing lifecycle contracts

**Files:**
- Modify: `tests/Controls.spec.luau`
- Modify: `tests/manual-smoke.luau`

**Step 1:** Add failing assertions for `setLayout` moving/resizing retained hit targets and visuals, returning omitted `Layout` to the default geometry, and preserving values without `Changed`.

**Step 2:** Add failing assertions for both controls hiding every primitive, releasing focus/capture/listening, rejecting hidden input, and restoring only persistent value/disabled state when shown.

**Step 3:** Run `lune run tests/run.luau` and confirm the new API is absent or behavior fails.

### Task 2: Add minimal Canvas capture release

**Files:**
- Modify: `src/InputRouter.luau`
- Modify: `src/Canvas.luau`

**Step 1:** Add a canvas-owned release operation that removes captures and hover state for an element without dispatching a click.

**Step 2:** Run the existing router and canvas tests to confirm pointer semantics remain unchanged.

### Task 3: Implement control layout and visibility

**Files:**
- Modify: `src/Controls.luau`

**Step 1:** Store current Position, Size, and optional Layout per control; make `setLayout` a complete replacement and recompute every owned primitive geometry/z-order.

**Step 2:** Add `setVisible(boolean)` that patches all owned primitives, disables interaction/focus, releases capture/focus, and cancels keybind listening when hidden.

**Step 3:** Run `lune run tests/run.luau` until all focused contracts pass.

### Task 4: Document and verify the published artifact

**Files:**
- Modify: `docs/consumer-contract.md`
- Modify: `examples/controls.luau`
- Modify: `tests/manual-smoke.luau`
- Modify: `dist/Limn.lua` (generated)

**Step 1:** Document the shared lifecycle API and constraints without application policy.

**Step 2:** Regenerate the bundle with `lune run scripts/build.luau`.

**Step 3:** Run Stylua, full tests, bundled manual smoke, `git diff --check`, and SHA-256 verification.

### Task 5: Publish the scoped result

**Files:**
- Commit only the plan, source, generated bundle, direct docs/example, and direct tests.

**Step 1:** Review the staged diff and commit in the existing imperative style.

**Step 2:** Push `codex/limn-generic-controls` and report its exact commit, bundle hash, checks, and clean state.
