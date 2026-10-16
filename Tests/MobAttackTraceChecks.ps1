$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$tracePath = Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MobAttackTrace.cs'
if (!(Test-Path -LiteralPath $tracePath)) { throw 'RED: MobAttackTrace is not implemented.' }
$trace = [IO.File]::ReadAllText($tracePath)
$harness = @'
namespace UnityEngine { public static class Debug { public static void Log(object value) {} } }
namespace NRO.Combat
{
    public struct MobAttackResult { public int Sequence; public byte Status; public byte SkillId; public byte MobId; public int RetryAfterMs; }
    public static class MobAttackResultTracker { public const byte Accepted=1, OutOfRange=2, Cooldown=3; }
}
public static class MobAttackTraceRegression
{
    public static string Run()
    {
        var lines = new System.Collections.Generic.List<string>();
        NRO.Combat.MobAttackTrace.Sink = lines.Add;
        NRO.Combat.MobAttackTrace.RecordSend(1, 12, 4, 7);
        NRO.Combat.MobAttackTrace.RecordResult(1, new NRO.Combat.MobAttackResult { Sequence=12, SkillId=4, MobId=7, Status=NRO.Combat.MobAttackResultTracker.Cooldown, RetryAfterMs=75 });
        NRO.Combat.MobAttackTrace.RecordHit(1, 7, 999, 1);
        if (lines.Count != 3) throw new System.Exception("Each attack boundary must emit one trace line.");
        if (!lines[0].Contains("SEND") || !lines[0].Contains("seq=12") || !lines[0].Contains("skill=4") || !lines[0].Contains("mob=7")) throw new System.Exception("Send trace must identify the attack.");
        if (!lines[1].Contains("RESULT") || !lines[1].Contains("status=COOLDOWN") || !lines[1].Contains("retryMs=75")) throw new System.Exception("Result trace must show the server status and retry interval.");
        if (!lines[2].Contains("HIT") || !lines[2].Contains("hp=999") || !lines[2].Contains("damage=1")) throw new System.Exception("Damage trace must preserve the received HP and damage values.");
        if (NRO.Combat.MobAttackTrace.StatusName(1) != "ACCEPTED" || NRO.Combat.MobAttackTrace.StatusName(2) != "OUT_OF_RANGE" || NRO.Combat.MobAttackTrace.StatusName(3) != "COOLDOWN" || NRO.Combat.MobAttackTrace.StatusName(0) != "REJECTED") throw new System.Exception("Every server status must be distinguishable.");
        return "PASS attack trace send/result/damage boundaries and status labels.";
    }
}
'@
Add-Type -TypeDefinition ($trace + "`n" + $harness) -Language CSharp
Write-Output ([MobAttackTraceRegression]::Run())

function Read-CaseBlock([string]$source, [string]$marker) {
    $start = $source.IndexOf($marker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing controller case: $marker" }
    $open = $source.IndexOf('{', $start)
    if ($open -lt 0) { throw "Missing case body: $marker" }
    $depth = 1
    $end = $open + 1
    while ($depth -gt 0 -and $end -lt $source.Length) {
        if ($source[$end] -eq '{') { $depth++ }
        if ($source[$end] -eq '}') { $depth-- }
        $end++
    }
    if ($depth -ne 0) { throw "Unclosed controller case: $marker" }
    return $source.Substring($start, $end - $start)
}

foreach ($game in @('Game1', 'Game2')) {
    $controller = [IO.File]::ReadAllText((Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/Controller.cs"))
    $resultBlock = Read-CaseBlock $controller 'case -48:'
    if ($resultBlock -notmatch 'MobAttackTrace\.RecordResult\(') { throw "$game must trace server attack results." }
    $hitBlock = Read-CaseBlock $controller 'case -9:'
    if ($hitBlock -notmatch 'MobAttackTrace\.RecordHit\(') { throw "$game must trace received damage packets." }
    $service = [IO.File]::ReadAllText((Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/Service.cs"))
    $sendBlock = Read-CaseBlock $service 'public bool TrySendPlayerAttack(MyVector vMob, MyVector vChar, int type, Action<MobAttackResult> resultCallback)'
    if ($sendBlock.IndexOf('session.sendMessage(message);', [StringComparison]::Ordinal) -gt $sendBlock.IndexOf('MobAttackTrace.RecordSend(', [StringComparison]::Ordinal)) { throw "$game send trace must be written only after the packet is handed to the session." }
    if ($sendBlock -notmatch 'MobAttackTrace\.RecordSend\(') { throw "$game must trace dispatched attack packets." }
}
Write-Output 'PASS both client lanes trace server results and mob damage packets.'
