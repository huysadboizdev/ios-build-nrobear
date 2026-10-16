$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$trackerPath = Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MobAttackResultTracker.cs'
$trackerSource = Get-Content -LiteralPath $trackerPath -Raw
$traceSource = (Get-Content -LiteralPath (Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MobAttackTrace.cs') -Raw) -replace '(?m)^using System;\s*', ''

foreach ($game in @('Game1', 'Game2')) {
    foreach ($relative in @('Char.cs', 'ModFunc.cs', 'Mod/XMAP/PickMobController.cs')) {
        $path = Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/$relative"
        if ([IO.File]::ReadAllText($path).Contains('HasPendingSkillFor(')) {
            throw "$game/$relative must not serialize ready punches behind a network ACK."
        }
    }
}
$harness = @'
public static class MobAttackResultRegression
{
    public static string Run()
    {
        NRO.Combat.MobAttackResultTracker.Clear();
        NRO.Combat.MobAttackResult accepted = new NRO.Combat.MobAttackResult();
        int acceptedCallbacks = 0;
        int sequence = NRO.Combat.MobAttackResultTracker.Begin(2, 7, result =>
        {
            acceptedCallbacks++;
            accepted = result;
        });
        if (sequence <= 0 || !NRO.Combat.MobAttackResultTracker.HasPending)
            throw new System.InvalidOperationException("A queued attack must remain pending until server confirmation.");
        if (!NRO.Combat.MobAttackResultTracker.HasPendingSkillFor(0, 2, 7))
            throw new System.InvalidOperationException("A pending massacre cast must block only duplicate casts of the same skill and target.");
        if (NRO.Combat.MobAttackResultTracker.HasPendingSkillFor(0, 2, 8)
            || NRO.Combat.MobAttackResultTracker.HasPendingSkillFor(0, 3, 7)
            || NRO.Combat.MobAttackResultTracker.HasPendingSkillFor(2, 2, 7))
            throw new System.InvalidOperationException("Pending casts must remain isolated by skill, target, and game lane.");
        if (!NRO.Combat.MobAttackResultTracker.CanAttempt(4, 1000))
            throw new System.InvalidOperationException("An unconfirmed attack must not block the next eligible cast.");
        int secondSequence = NRO.Combat.MobAttackResultTracker.Begin(4, 8, null);
        if (secondSequence <= 0 || secondSequence == sequence)
            throw new System.InvalidOperationException("Each attack must keep an independent in-flight result.");
        if (!NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = sequence, Status = NRO.Combat.MobAttackResultTracker.Accepted,
            PlayerX = 130, PlayerY = 100, MobX = 200, MobY = 100
        }, 1000))
            throw new System.InvalidOperationException("The server result must resolve the matching request.");
        if (acceptedCallbacks != 1 || accepted.Status != NRO.Combat.MobAttackResultTracker.Accepted
            || accepted.SkillId != 2 || accepted.MobId != 7 || accepted.MobX != 200)
            throw new System.InvalidOperationException("The accepted result must preserve the request and authoritative target.");
        if (!NRO.Combat.MobAttackResultTracker.HasPending || !NRO.Combat.MobAttackResultTracker.CanAttempt(4, 1000))
            throw new System.InvalidOperationException("Resolving one sequence must preserve other in-flight attacks without blocking them.");
        NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = secondSequence, Status = NRO.Combat.MobAttackResultTracker.Accepted
        }, 1100);

        int acceptedWithCooldown = NRO.Combat.MobAttackResultTracker.Begin(6, 12, null);
        NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = acceptedWithCooldown, Status = NRO.Combat.MobAttackResultTracker.Accepted, RetryAfterMs = 300
        }, 5000);
        if (!NRO.Combat.MobAttackResultTracker.CanAttempt(6, 5000))
            throw new System.InvalidOperationException("Accepted ACK must not add a new wait to the predicted skill cooldown.");

        int rejected = NRO.Combat.MobAttackResultTracker.Begin(4, 9, null);
        NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = rejected, Status = NRO.Combat.MobAttackResultTracker.Rejected, RetryAfterMs = 500
        }, 2000);
        if (NRO.Combat.MobAttackResultTracker.CanAttempt(4, 2499)
            || !NRO.Combat.MobAttackResultTracker.CanAttempt(4, 2500))
            throw new System.InvalidOperationException("A rejected cast must honor the server retry delay.");

        int obsolete = NRO.Combat.MobAttackResultTracker.Begin(8, 10, result => { throw new System.Exception("Stale callback executed"); });
        int current = NRO.Combat.MobAttackResultTracker.Begin(8, 10, null);
        if (NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = obsolete, Status = NRO.Combat.MobAttackResultTracker.Cooldown, RetryAfterMs = 500
        }, 4000) || !NRO.Combat.MobAttackResultTracker.CanAttempt(8, 4000))
            throw new System.Exception("An old rejection must not block a newer cast or resync its coordinates.");
        if (!NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = current, Status = NRO.Combat.MobAttackResultTracker.Accepted, RetryAfterMs = 350
        }, 4100)) throw new System.Exception("Newest result must still resolve.");
        if (NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = current, Status = NRO.Combat.MobAttackResultTracker.Accepted
        }, 4200)) throw new System.Exception("Duplicate ACK must resolve exactly once.");

        NRO.Combat.MobAttackResultTracker.ClearFor(1);
        NRO.Combat.MobAttackResultTracker.ClearFor(2);
        int game1 = NRO.Combat.MobAttackResultTracker.BeginFor(1, 3, 2, null);
        if (game1 <= 0 || !NRO.Combat.MobAttackResultTracker.CanAttemptFor(1, 3, 4000)
            || !NRO.Combat.MobAttackResultTracker.HasPendingFor(1)
            || NRO.Combat.MobAttackResultTracker.HasPendingFor(2))
            throw new System.InvalidOperationException("Game1 and Game2 confirmations must remain isolated without serializing attacks.");
        NRO.Combat.MobAttackResultTracker.ClearFor(1);

        int outOfRange = NRO.Combat.MobAttackResultTracker.Begin(0, 9, null);
        NRO.Combat.MobAttackResultTracker.Resolve(new NRO.Combat.MobAttackResult {
            Sequence = outOfRange, Status = NRO.Combat.MobAttackResultTracker.OutOfRange
        }, 3000);
        if (!NRO.Combat.MobAttackResultTracker.CanAttempt(0, 3000))
            throw new System.InvalidOperationException("Out-of-range casts must retry immediately after repositioning.");
        NRO.Combat.MobAttackResultTracker.Begin(1, 10, null);
        NRO.Combat.MobAttackResultTracker.Clear();
        if (NRO.Combat.MobAttackResultTracker.HasPending || !NRO.Combat.MobAttackResultTracker.CanAttempt(1, 9000))
            throw new System.InvalidOperationException("Clearing on disconnect or map change must release all pending state.");
        return "PASS mob attack results: acceptance, rejection cooldown, range retry, pending cleanup";
    }
}
'@
Add-Type -TypeDefinition ($trackerSource + "`n" + $traceSource + "`nnamespace UnityEngine { public static class Debug { public static void Log(object value) {} } }" + "`n" + $harness) -Language CSharp
[MobAttackResultRegression]::Run()
