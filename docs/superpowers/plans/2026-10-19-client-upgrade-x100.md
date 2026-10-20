# Client upgrade x100 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add an x100 upgrade action to both client variants, spending protection stones when that upgrade recipe shows them and stopping as soon as the server reports a successful upgrade.

**Architecture:** Add a small shared state machine that permits one request at a time and coordinates the batch with the existing combine response and animation lifecycle. Add a second action row to the combine panel for x100 while keeping the existing one-at-a-time row. Keep server costs and outcomes authoritative; mirror UI and response wiring in `Game1` and `Game2`.

**Tech Stack:** Unity C# client source, existing `Service.combine` protocol (`-81`), Python source regression checks, C# harness for the batch state machine.

---

## File map

- Create `Assets/Scripts/Assembly-CSharp/UpgradeBatchState.cs`: shared, Unity-independent batch state for maximum attempts, request-in-flight tracking, response handling, stop, and cancel.
- Modify `Assets/Scripts/Assembly-CSharp/Game1/Panel.cs` and `Game2/Panel.cs`: draw and route the extra x100 row, detect whether the active recipe shows a protection stone, count available protection stones, start/cancel a batch, and dispatch the next attempt after a failed attempt's existing effect finishes.
- Modify `Assets/Scripts/Assembly-CSharp/Game1/Controller.cs` and `Game2/Controller.cs`: report ordinary upgrade response outcomes to the active batch using the actual protocol mapping (`b32 == 2` success; `b32 == 3` failure), while preserving the existing combine effect path.
- Create `Tests/UpgradeBatchStateTests.cs`: compile and exercise the shared state machine without launching Unity.
- Create `Tests/UpgradeX100Checks.py`: source-level checks for both client variants, the UI routing, response mapping, and the protection-cost gate.

## Task 1: Add regression coverage for batch state

**Files:**
- Create: `Tests/UpgradeBatchStateTests.cs`
- Create: `Assets/Scripts/Assembly-CSharp/UpgradeBatchState.cs`

- [x] **Step 1: Write the state-machine harness first**

Create `Tests/UpgradeBatchStateTests.cs` with this complete harness:

```csharp
using System;

class UpgradeBatchStateTests
{
    static void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
    }

    static void Main()
    {
        UpgradeBatchState state = new UpgradeBatchState();
        state.Start(100);
        Check(state.TryMarkRequestSent(), "first request must be accepted");
        Check(!state.TryMarkRequestSent(), "must reject a parallel request");
        Check(state.OnResponse(false), "failure response must be accepted");
        Check(!state.TryMarkRequestSent(), "must wait for failed-attempt effect");
        Check(state.OnEffectFinished(), "failed-attempt effect must release next send");
        Check(state.TryMarkRequestSent(), "next request must be accepted after effect");
        Check(state.OnResponse(true), "success response must be accepted");
        Check(!state.IsActive, "success must stop the batch immediately");
        Check(!state.TryMarkRequestSent(), "success must prevent another request");
        Check(!state.OnResponse(false), "duplicate response must be ignored");

        state.Start(100);
        for (int i = 0; i < 100; i++)
        {
            Check(state.TryMarkRequestSent(), "attempt " + (i + 1) + " must be accepted");
            Check(state.OnResponse(false), "failure response " + (i + 1) + " must be accepted");
            if (i < 99) Check(state.OnEffectFinished(), "effect " + (i + 1) + " must release next send");
        }
        Check(!state.IsActive, "100 failed attempts must stop the batch");
        Check(!state.OnResponse(false), "unsolicited response must be ignored");

        state.Start(100);
        Check(state.TryMarkRequestSent(), "request before cancel must be accepted");
        state.Cancel();
        Check(!state.IsActive && !state.TryMarkRequestSent(), "cancel must stop future sends");
        Console.WriteLine("PASS upgrade batch state: sequential requests, first-success stop, 100-attempt limit, effect wait, cancellation, duplicate-response guard");
    }
}
```

- [x] **Step 2: Compile and run the harness to establish the failing baseline**

First create `UpgradeBatchState.cs` with the public API used by the harness and inert methods (`Start`/`Cancel` do nothing, properties return defaults, and boolean methods return `false`). This makes the harness compile while ensuring its first assertion fails.

Run in PowerShell:

```powershell
$testExe = Join-Path $env:TEMP 'UpgradeBatchStateTests.exe'
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo "/out:$testExe" Tests\UpgradeBatchStateTests.cs Assets\Scripts\Assembly-CSharp\UpgradeBatchState.cs
& $testExe
```

Expected before implementation: compilation succeeds and the harness exits nonzero with `first request must be accepted`.

- [x] **Step 3: Implement the shared state machine**

Expose methods for `Start(100)`, `TryMarkRequestSent()`, `OnResponse(bool success)`, `OnEffectFinished()`, and `Cancel()`. Track attempts sent and whether a request or failed-attempt effect is pending. A success response changes the state to stopped immediately. A failure response can permit the next send only after `OnEffectFinished()`. Refuse sends after 100 attempts, after cancellation, while awaiting a response, or while awaiting the effect.

- [x] **Step 4: Run the state-machine harness**

Run in PowerShell:

```powershell
$testExe = Join-Path $env:TEMP 'UpgradeBatchStateTests.exe'
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo "/out:$testExe" Tests\UpgradeBatchStateTests.cs Assets\Scripts\Assembly-CSharp\UpgradeBatchState.cs
& $testExe
```

Expected: `PASS upgrade batch state: sequential requests, first-success stop, 100-attempt limit, effect wait, cancellation, duplicate-response guard`.

## Task 2: Add x100 UI and protection-stone eligibility in Game1

**Files:**
- Modify: `Assets/Scripts/Assembly-CSharp/Game1/Panel.cs` (`setTabCombine`, `updateKeyCombine`, `paintCombine`, `doFireCombine`)

- [x] **Step 1: Add the x100 row and route it independently**

Keep the existing row at `selected == vItemCombine.size()` for one upgrade. Add one row at `selected == vItemCombine.size() + 1`, label it `Nâng cấp x100`, and update list length, touch selection, scrolling, selected-row paint, and keyboard/controller routing. Confirm the one-at-a-time row still calls the existing single-upgrade path.

- [x] **Step 2: Add recipe-aware protection detection and inventory counting**

Use the server-provided `combineInfo` and `combineTopInfo` for the currently open recipe to detect whether it displays a protection-stone requirement. Resolve the matching protection item from the loaded item templates, then sum its available bag quantity. Keep this detection in one helper so both button text and start validation use the same result. Show `Nâng cấp x100 (100 đá bảo vệ)` when protection is required and show `Nâng cấp x100` otherwise. If protection is required and fewer than 100 are available, keep x100 visible but disable its action and show an existing `GameScr.info1.addInfo(...)` message explaining the shortfall. Do not block x100 for recipes that display no protection stone.

- [x] **Step 3: Wire the x100 action to the shared state without sending a burst**

On x100 activation, validate that the active panel is the ordinary upgrade recipe and that protection inventory passes the gate when applicable. Initialize the state machine with 100 attempts, mark the first request sent, and call `Service.gI().combine(1, vItemCombine)` once. Store that the pending response belongs to x100 so a normal one-at-a-time upgrade never enters batch handling.

- [x] **Step 4: Add source regression checks for the Game1 UI path**

Create assertions in `Tests/UpgradeX100Checks.py` that verify a separate x100 selection row, unchanged single-upgrade dispatch, protection display detection, the minimum-100 gate, and a single initial combine send. Keep tests structural and tied to named methods/branches rather than full-file text snapshots.

## Task 3: Connect Game1 responses and effect completion

**Files:**
- Modify: `Assets/Scripts/Assembly-CSharp/Game1/Controller.cs` (packet `-81`, response values `b32 == 2` and `b32 == 3`)
- Modify: `Assets/Scripts/Assembly-CSharp/Game1/Panel.cs` (`updateCombineEff`, batch response/effect callbacks)

- [x] **Step 1: Feed ordinary upgrade outcomes into the active batch**

For the ordinary upgrade response path, pass `success: true` on `b32 == 2` and `success: false` on `b32 == 3`. Preserve all current assignments to `combineSuccess` and calls to `setCombineEff(0)`. Do not treat `b32` values 4 through 8 as ordinary upgrade outcomes.

- [x] **Step 2: Stop on success and continue only after a failed effect completes**

On success, stop the batch immediately and let the existing success effect and `mResources.combineSuccess` notification finish normally. On failure, wait until `updateCombineEff` reaches the existing `isDoneCombine = true` transition; then call `OnEffectFinished()`, mark exactly one next request as sent, and send it. If the attempt limit is reached, do not send another request.

- [x] **Step 3: Cancel safely on invalidation**

Cancel the active batch when the combine recipe is replaced, the panel closes, the selected material list changes, the session disconnects, or request sending throws/fails. Clear the batch pending marker on every terminal path. Preserve the existing wait dialog, result animation, and NPC notice behavior.

- [x] **Step 4: Add response/effect assertions to the regression check**

Assert that `b32 == 2` maps to success and stops before another send, `b32 == 3` maps to failure and dispatches only after `isDoneCombine`, and non-upgrade response values do not advance the batch.

## Task 4: Mirror and cross-check Game2

**Files:**
- Modify: `Assets/Scripts/Assembly-CSharp/Game2/Panel.cs` (same UI and batch methods as Game1)
- Modify: `Assets/Scripts/Assembly-CSharp/Game2/Controller.cs` (same `-81` outcome mapping)
- Modify: `Tests/UpgradeX100Checks.py`

- [x] **Step 1: Apply the Game1 behavior to Game2**

Mirror the same row ordering, label text, protection gate, batch start/cancel conditions, response mapping, and wait-until-effect-completes logic. Keep the code compatible with the existing C# language level and local patterns in `Game2`.

- [x] **Step 2: Check parity in the source regression script**

Run: `python Tests/UpgradeX100Checks.py`

Expected: `PASS Game1 and Game2: x100 UI, protection gate, server outcome mapping, sequential dispatch, cancellation parity`.

## Task 5: Final source verification

**Files:**
- Verify: all files listed above
- Verify: unrelated working tree edits remain untouched

- [x] **Step 1: Run the focused checks**

Run in PowerShell:

```powershell
$testExe = Join-Path $env:TEMP 'UpgradeBatchStateTests.exe'
& $testExe
```

Run: `python Tests/UpgradeX100Checks.py`

Expected: both commands pass with the messages specified above.

- [x] **Step 2: Review the final diff and working tree**

Run: `git diff --check`

Run: `git status --short`

Expected: no whitespace errors; only the planned client source and focused regression files are changed, while pre-existing `Assets/Scripts/Assembly-CSharp/Management.cs` remains untouched. Do not run a Unity build or package an APK, EXE, or JAR unless separately requested.


## Implementation report — 2026-10-20

Implemented directly in the existing checkout, as authorized by the user. No application build or packaging was run.

Server source inspection corrected the original plan's assumption: `combine(1, items)` opens the NPC price/confirmation menu; actual attempts require `confirmMenu(21, 0)`. Both Controller menu paths now offer x100 on the ordinary equipment upgrade confirmation and automatically confirm only validated upgrade menus during an active batch. The protection item ID is 987 and the current server charges one protection stone per attempt. The client preserves the selected input list and does not add protection items from the bag automatically. A protected run requires 100 stones initially and consumes only the attempts actually performed before success or cancellation.

Server packet `-81` subtype 1 reopens the selected item list after each result. This refresh updates the batch signature instead of unconditionally canceling a failed batch. Subtype 2 stops immediately on success; subtype 3 waits until the existing effect finishes before requesting the next confirmation. Invalid/insufficient-material menus, disconnects, changed inputs and panel closure stop the batch; a 15 second pending-response limit stops retries when no result arrives. Existing automatic crystal upgrading must be disabled before starting x100 to avoid competing senders.

Validation: `Tests/UpgradeBatchStateTests.cs` exercises the shared state machine; `python Tests/UpgradePanelHarnessChecks.py` compiles and executes the actual extracted panel methods for both namespaces, including protection 99/100, no protection, NPC confirmation, failed result/reopen/effect continuation, success stop, 100 limit, invalid menus, and cancellation. `python Tests/UpgradeX100Checks.py` checks source integration and parity. `git diff --check` verifies whitespace. Harness binaries are written only to temporary directories. Full Unity UI/server gameplay has not been exercised.

The pre-existing `Management.cs` edit was preserved. Git metadata is read-only, so no commit was created.


### Protection auto-selection correction — 2026-10-20

User clarified that protection stones already in the bag must appear and be selected automatically. Both panels now add the available item 987 to the visible combine inputs as soon as an ordinary equipment upgrade pair is selected, with duplicate prevention. Both single and x100 dispatch ensure protection is included. This supersedes the earlier note that protection was never added automatically. A protected batch will not auto-confirm any server menu lacking protection costs. Regression coverage includes bag-only protection, repeated selection, and rejection of unprotected confirmation.
