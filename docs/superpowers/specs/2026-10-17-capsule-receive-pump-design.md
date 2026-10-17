# Capsule receive pump correction

The user approved implementation of the investigation's proposed receive-order fix on 2026-10-17. Work in the existing client checkout so its current uncommitted map and pathfinding fixes remain available. Do not build APK, EXE or JAR, commit, deploy, or modify server state.

Use a locked FIFO Queue<Message> in all four sessions. Always enqueue incoming packets, including main-thread callers. Dispatch one packet at a time outside the queue lock; check Controller.isStopReadMessage before each dequeue. A capsule departure must retain all following map packets until its existing Teleport animation releases that flag. New arrivals must remain behind older packets, including when a handler throws.

Process at most 64 packets and approximately 2 milliseconds per session per Unity frame, using Time.frameCount and Stopwatch timestamps. The deadline is cooperative between handlers: one expensive handler can exceed it. A repeated OnGUI event in the same frame must not spend another budget. Empty or paused calls must not consume a frame's budget. This bounds the identified packet-burst path; it does not claim to fix every possible source of Android lag.

Alternatives considered: merely break the existing batch loop loses packets because the entire queue has already been cleared; resetting the stop flag at map entry allows map packets to erase departure animation. FIFO dispatch addresses the cause and retains existing map behavior.

Verify production dispatch methods with an in-memory C# harness, modeling the capsule lifecycle only at handler boundaries. Cover same-batch suspension, resume and FIFO with new arrivals, missing-resource map completion, repeated frame calls, packet count/time budgets, empty/paused frames, handler exceptions and background-thread enqueue. Adapt the existing Editor regression to the queue API and bounded behavior. Validate no application artifacts are built and preserve unrelated changes.
