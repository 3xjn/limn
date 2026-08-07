# Segmented Rounded Non-overlap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove alpha-banding seams from positive-radius SegmentedControl rendering without changing `CornerRadius` or any interaction contract.

**Architecture:** Replace overlapping cross-Squares and full Circles with an interior/edge Square partition and four Triangle fans. The five Squares tile the rectangular interior and bridges; each corner fan tiles only its own quarter-circle sector. Pieces meet at boundaries, never overlap in their interiors, so every pixel receives the selected visual style once.

**Tech Stack:** Luau, Lune, Stylua, retained Volt Drawing primitives, fake Drawing backend, SVG/PNG preview.

---

### Task 1: Add failing non-overlap contracts

**Files:**
- Modify: `tests/Controls.spec.luau`
- Modify: `tests/Bundle.spec.luau`

**Step 1: Write analytical source checks.**

For normal and clamped layouts, assert the five Square regions meet only at boundaries and the four Triangle fans have consecutive, disjoint angular sectors. Also retain assertions for rectangular targets, state precedence, labels, visibility, disabled behavior, cleanup, zero-radius equivalence, and unsupported primitive failure.

**Step 2: Add equivalent bundled checks.**

Load `dist/Limn.lua`, assert the retained Triangle-based helper composition and no-overlap geometry, and verify construction fails clearly if retained Triangle support is absent.

**Step 3: Run before implementation.**

Run: `lune run tests/run.luau`

Expected: rounded contracts fail because the existing Circle composition has overlapping interiors.

### Task 2: Replace the rounded visual decomposition

**Files:**
- Modify: `src/Controls.luau`

**Step 1: Replace Circle helpers with Triangle fan helpers.**

Use a fixed number of arc sectors per corner. Generate points from the clamped radius, corner center, and quarter-circle angles. The fan triangles share only the center and adjacent arc edges.

**Step 2: Partition the rectangular fill.**

Use center, top, bottom, left, and right Squares. Assign all pieces the existing state patches and final control geometry/ZIndex/visibility updates. Keep original segment Squares as transparent rectangular input targets.

**Step 3: Verify source behavior.**

Run: `lune run tests/run.luau`

Expected: source controls pass; bundled checks remain stale until regeneration.

### Task 3: Refresh direct artifacts and publish

**Files:**
- Modify: `docs/consumer-contract.md`
- Modify: `tests/manual-smoke.luau`
- Modify: `dist/Limn.lua` (generated)
- Create: untracked SVG/PNG preview under `C:/Users/asher/.codex/visualizations/2026/08/06/019fd480-7423-7363-b29d-9c5ec68621cc/limn-rounded-preview/`

**Step 1: Update the primitive-capability documentation.**

Describe the accurate retained primitive requirement while retaining the unchanged public option semantics.

**Step 2: Generate and inspect a fresh preview.**

Serialize actual bundled-runtime retained objects with semi-transparent selected/hover/focus/disabled styles, rasterize the result, and inspect it directly. Obtain two independent read-only visual QA verdicts with no seam or banding blocker.

**Step 3: Run final validation and publish.**

Run Stylua, build, full tests, bundled manual smoke, diff checks, SHA-256, and available diagnostics. Commit only the scoped follow-up, then push `codex/limn-generic-controls`.
