# Capsule receive pump implementation plan

**Goal:** Fix capsule receive suspension and bound main-thread receive bursts in both tabs.

**Architecture:** Locked Queue<Message>, per-handler stop checks, a 64-packet/2 ms cooperative budget once per frame. Existing map/Teleport lifecycle remains responsible for resume.

**Tech Stack:** Unity C#, PowerShell Add-Type behavioral checks without building a player.

## Tasks

- [x] Add `Tests/CapsuleReceiveChecks.ps1`, extracting actual receive members from the four sessions. First prove the old code processes the map packet after capsule suspension.
- [x] Modify `Assets/Scripts/Assembly-CSharp/Game{1,2}/Session_ME{,2}.cs`: change the receive collection to Queue<Message>, always enqueue, check stop before dequeue, dispatch outside lock, cap work per frame by count/time.
- [x] Verify pause/resume, ordering, missing-resource completion, count/time limits, repeated frame callbacks, callback failure and concurrent arrival on all four sessions.
- [x] Update `Assets/Editor/ReceiveQueueBudgetRegression.cs` to Queue APIs, preserve old stop state, and check same-frame budget behavior with a large queue.
- [x] Run receive checks and existing outgoing queue checks, inspect scoped diffs/whitespace, and record limits and validation. Do not build application packages.

## Verification results

- RED: old production receivers failed capsule suspension, frame/time budget, exception tail retention and main-thread ordering checks in all four sessions.
- GREEN: `powershell -NoProfile -ExecutionPolicy Bypass -File Tests/CapsuleReceiveChecks.ps1` passed six scenarios per session, 24 total. Capsule cases cover local and server-provided map resources.
- Existing outgoing queue stress passed 160,000 messages, exactly once.
- Scoped whitespace checks passed; independent reviewer found no significant issue and reran all receive cases successfully.
- Updated the Editor regression API/assertions; it was not run inside Unity. No Unity/Android runtime test or APK/EXE/JAR build was performed. Device smoothness still requires verification on a future authorized APK build.
