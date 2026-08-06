# Control Layout and Visibility Audit Follow-up Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the hidden-inert and geometry-precedence contracts for Limn's existing generic controls.

**Architecture:** Extend only the focused control contract tests and make control geometry the final patch after state/style refreshes. Do not alter the public API or add application behavior.

**Tech Stack:** Luau, Lune, Stylua, fake Volt Drawing backend.

---

### Task 1: Write failing contract coverage

**Files:**
- Modify: `tests/Controls.spec.luau`

**Step 1:** Assert new pointer down/up sequences on hidden segmented and keybind controls cannot focus, capture, change a value, or begin listening; assert hidden keybind `begin()` and keyboard input are inert.

**Step 2:** Give both controls conflicting `Position`/`Size` style properties, call `setLayout`, then toggle disabled/visible state and assert geometry remains authoritative.

**Step 3:** Run `lune run tests/run.luau` and confirm the new assertions fail.

### Task 2: Make layout final

**Files:**
- Modify: `src/Controls.luau`

**Step 1:** Reapply each control's stored layout geometry after state/style patches in every visual refresh path.

**Step 2:** Run `lune run tests/run.luau` and confirm all contracts pass.

### Task 3: Publish the audited artifact

**Files:**
- Modify: `dist/Limn.lua` (generated)
- Modify: `tests/manual-smoke.luau` only if the bundled smoke needs direct coverage

**Step 1:** Format, rebuild, run the full suite and bundled smoke, inspect the SHA-256, and run `git diff --check`.

**Step 2:** Commit only this plan, the focused source/test/bundle changes, and push the worker branch.
