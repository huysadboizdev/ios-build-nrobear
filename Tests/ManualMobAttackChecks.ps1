$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$traceSource = [IO.File]::ReadAllText((Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MobAttackTrace.cs')) -replace '(?m)^using System;\s*', ''
function Read-Block([string]$source, [string]$marker) {
    $start = $source.IndexOf($marker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing source block: $marker" }
    $open = $source.IndexOf('{', $start)
    $depth = 1
    $end = $open + 1
    while ($depth -gt 0 -and $end -lt $source.Length) {
        if ($source[$end] -eq '{') { $depth++ }
        if ($source[$end] -eq '}') { $depth-- }
        $end++
    }
    return $source.Substring($start, $end - $start)
}
$tracker = [IO.File]::ReadAllText((Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MobAttackResultTracker.cs'))
$template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ManualMobAttackHarness.cs.txt'))
$source = $tracker + "`n" + $traceSource + "`nnamespace UnityEngine { public static class Debug { public static void Log(object value) {} } }"
$source += [IO.File]::ReadAllText((Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MassacreAttackRange.cs'))
foreach ($entry in @(@('Game1', 1), @('Game2', 2))) {
    $game = $entry[0]
    $char = [IO.File]::ReadAllText((Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/Char.cs"))
    $mod = [IO.File]::ReadAllText((Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/ModFunc.cs"))
    $setUsed = Read-Block $mod 'public void SetUsedSkill(Skill skill, int retryAfterMs)'
    $auto = Read-Block $mod 'public void AutoAttack()'
    $setUsedLocal = Read-Block $mod 'public void SetUsedSkill(Skill skill)'
    $massacreSource = [IO.File]::ReadAllText((Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/Mod/XMAP/PickMobController.cs"))
    $massacre = ''
    foreach ($method in @('private static bool IsExcludedMassacreSkill(', 'private static int NextMassacreSkillCursor(', 'private static Skill GetSkillAttack(bool mobTarget)', 'private static void AdvanceMassacreSkillCursor(', 'private static bool TryUseMassacreSkill(', 'private static bool CanUseSkill(', 'private static long GetManaUseSkill(', 'private static bool EnsurePositionSent()')) {
        $massacre += Read-Block $massacreSource $method
    }
    $screen = [IO.File]::ReadAllText((Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/GameScr.cs"))
    $attack = Read-Block $screen 'public bool isAttack()'
    $approachStart = $attack.IndexOf('int num3 = Math.abs')
    $approachIf = $attack.IndexOf('if (', $approachStart)
    $approachOpen = $attack.IndexOf('{', $approachIf)
    $approachCondition = $attack.Substring($approachIf + 3, $approachOpen - $approachIf - 3).Trim()
    $retry = (Read-Block $char 'private void cancelPendingManualMobRetry()') + (Read-Block $char 'private void scheduleManualMobRetry(') + (Read-Block $char 'private void updatePendingManualMobRetry()')
    $send = Read-Block $char 'if (me && !isSelectingSkillUseAlone() && !hasSendAttack)'
    $start = Read-Block $char 'public void setSkillPaint(SkillPaint skillPaint, int sType)'
    $cut = $start.IndexOf('long manaBeforeSkillPaint')
    if ($cut -lt 0) { $cut = $start.IndexOf('if (myskill.template.manaUseType == 2)') }
    if ($cut -lt 0) { throw 'Cannot isolate real animation validation.' }
    $start = $start.Substring(0, $cut) + 'AnimationStarts++; } }'
    $source += $template.Replace('__GAME__', $game).Replace('__LANE__', [string]$entry[1]).Replace('__RETRY__', $retry).Replace('__SEND__', $send).Replace('__START__', $start).Replace('__SET_USED__', $setUsed).Replace('__SET_USED_LOCAL__', $setUsedLocal).Replace('__AUTO__', $auto).Replace('__MASSACRE__', $massacre).Replace('__APPROACH_CONDITION__', $approachCondition)
}
Add-Type -TypeDefinition $source -Language CSharp
$failures = [Game1.ManualMobAttackHarness]::Run() + [Game2.ManualMobAttackHarness]::Run()
if ($failures -ne 0) { throw "$failures manual mob attack regressions failed." }
Write-Output 'PASS real manual attack callbacks and retry methods for both game lanes.'
