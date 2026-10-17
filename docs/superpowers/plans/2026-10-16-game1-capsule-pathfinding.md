# Game1 Capsule Pathfinding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Keep Game1 capsule route search bounded so route calculation does not stall the Android main thread.

**Architecture:** Add a graph-provider overload to Game1's XMAP algorithm and use two-pass breadth-first search, first excluding the known undesirable transition and then allowing it as fallback. Extend the existing editor regression suite to exercise Game1 independently of live map state.

**Tech Stack:** Unity C#, existing Editor regression harness.

---

### Task 1: Add Game1 pathfinding regression coverage

**Files:**
- Modify: `Assets/Editor/XmapAlgorithmRegression.cs`

- [x] Add aliases for Game1's XmapAlgorithm and use small directed graphs to assert shortest route and edge-order determinism, null when unreachable, start equals end, known undesirable-route avoidance/fallback, and bounded graph expansion for a branching capsule graph.
- [x] Invoke the test harness and confirm it fails because the graph-provider overload does not yet exist.

### Task 2: Replace recursive search with BFS

**Files:**
- Modify: `Assets/Scripts/Assembly-CSharp/Game1/Mod/XMAP/XmapAlgorithm.cs`

- [x] Add `System` and collection imports; add the graph-provider overload; adapt live map edges through a private iterator.
- [x] Implement BFS over `(previous,current)` states, retaining deterministic neighbor order, first excluding `27|28|29 -> 102 -> 24`, then retrying with that route allowed.
- [x] Run the regression harness and confirm all Game1 and existing Game2 XMAP checks pass.

### Task 3: Review changes

**Files:**
- Review: `Assets/Scripts/Assembly-CSharp/Game1/Mod/XMAP/XmapAlgorithm.cs`
- Review: `Assets/Editor/XmapAlgorithmRegression.cs`

- [x] Inspect the final diff and run whitespace/diff checks; do not invoke any APK or other player build.

### Task 4: Remove duplicate map-transition full collections

**Files:**
- Modify: `Assets/Scripts/Assembly-CSharp/Game1/Controller.cs`
- Modify: `Assets/Scripts/Assembly-CSharp/Game2/Controller.cs`

- [x] Remove the direct `Resources.UnloadUnusedAssets()` and `GC.Collect()` pair after waypoint parsing in each `loadInfoMap` path.
- [x] Remove the direct pair immediately after `loadCurrMap(teleport)` in each map completion path; preserve `mSystem.gcc()` at map entry and tile replacement.
- [x] Verify both controller sources contain no direct unload/collect pairs, run XMAP regressions, and inspect the diff.
