# Segmented Selected Label Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add generic `Style.SelectedLabel` state to SegmentedControl's existing retained label primitives.

**Architecture:** Keep all work in the segmented visual refresh path: apply `Label`, overlay `SelectedLabel` only for the selected option, then reapply control-owned geometry and visibility. No primitives, public seams, or application behavior are added.

**Tech Stack:** Luau, Lune, Stylua, fake Volt Drawing backend.

---

### Task 1: Add failing selected-label contracts

**Files:**
- Modify: `tests/Controls.spec.luau`
- Modify: `tests/Bundle.spec.luau`

**Step 1:** Assert initial selected and unselected label properties, `setValue` transfer/reset, and constant primitive counts.

**Step 2:** Assert square hover/focus/disabled styling coexists with selected-label styling, and conflicting label geometry/visibility cannot override layout or visibility.

**Step 3:** Run `lune run tests/run.luau` and confirm the new source and bundled contracts fail.

### Task 2: Apply selected-label state

**Files:**
- Modify: `src/Controls.luau`

**Step 1:** Apply `Style.Label` to every existing label and overlay `Style.SelectedLabel` only on the selected label.

**Step 2:** Keep geometry, ZIndex, and Visible final after text style patches, then run the source contracts.

### Task 3: Document and publish the artifact

**Files:**
- Modify: `docs/consumer-contract.md`
- Modify: `examples/controls.luau`
- Modify: `tests/manual-smoke.luau` only if needed
- Modify: `dist/Limn.lua` (generated)

**Step 1:** Document exact text and square precedence plus Label reset behavior.

**Step 2:** Format, rebuild, run all tests and bundled smoke, inspect SHA-256, and check the diff.

**Step 3:** Commit only these direct artifacts and push the worker branch.
