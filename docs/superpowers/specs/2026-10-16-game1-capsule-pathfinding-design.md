# Game1 capsule pathfinding design

## Problem

After capsule map selection, Game1 builds the XMAP graph and searches a route. Its recursive depth-first search enumerates candidate simple paths and can expand exponentially on the graph with capsule links, stalling the Unity main thread on Android. Game2 already has a bounded breadth-first implementation, but Game1 still has the older recursive implementation.

## Design

Replace Game1's recursive route enumeration with breadth-first search. Preserve adjacency order so equally short routes remain deterministic. Search first while excluding the known undesirable transition `27|28|29 -> 102 -> 24`, then retry without that restriction if no route exists. Track `(previous,current)` states so this transition rule remains correct without revisiting equivalent search states. Return `null` for unreachable destinations and a one-map route when start equals destination.

Expose a graph-provider overload on Game1's algorithm, matching the existing Game2 test seam. Add editor regression coverage for shortest-path ordering, unreachable and same-map requests, the undesirable transition preference/fallback, and bounded work on a branching capsule graph.

## Scope and verification

Change Game1 XMAP pathfinding and the existing XMAP editor regression harness. Also remove the duplicated synchronous `Resources.UnloadUnusedAssets()` plus `GC.Collect()` calls from `loadInfoMap` and immediately after `loadCurrMap` in both Game1 and Game2. Preserve the map-entry cleanup and tile replacement cleanup. Run the XMAP regression harness and verify the duplicated cleanup calls are absent without invoking an Android build.
