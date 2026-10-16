$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repo 'Assets/Scripts/Assembly-CSharp/MassacreAttackRange.cs'
if (-not (Test-Path -LiteralPath $helperPath)) {
    throw 'Missing massacre attack range helper.'
}

$controllers = @(
    'Assets/Scripts/Assembly-CSharp/Game1/Mod/XMAP/PickMobController.cs',
    'Assets/Scripts/Assembly-CSharp/Game2/Mod/XMAP/PickMobController.cs'
)
foreach ($relativePath in $controllers) {
    $source = Get-Content -LiteralPath (Join-Path $repo $relativePath) -Raw
    if ($source -notmatch 'MassacreAttackRange\.IsWithinSkillRange') {
        throw "$relativePath does not use the safe server-compatible attack range."
    }
    if ($source -notmatch 'MassacreAttackRange\.GetApproachOffset') {
        throw "$relativePath does not approach to a safe melee distance."
    }
}

foreach ($relativePath in @(
    'Assets/Scripts/Assembly-CSharp/Game1/Char.cs',
    'Assets/Scripts/Assembly-CSharp/Game2/Char.cs'
)) {
    $source = Get-Content -LiteralPath (Join-Path $repo $relativePath) -Raw
    if ($source -notmatch 'MassacreAttackRange\.IsWithinSkillRange') {
        throw "$relativePath does not filter manual mob targets against the server melee range."
    }
}

$helperSource = Get-Content -LiteralPath $helperPath -Raw
$harness = @'
public static class MassacreRangeRegression
{
    public static string Run()
    {
        if (NRO.Combat.MassacreAttackRange.IsWithinSafeRange(80, 80, 120, 120))
            throw new System.InvalidOperationException("Diagonal point outside server range was accepted.");
        if (!NRO.Combat.MassacreAttackRange.IsWithinSafeRange(50, 50, 120, 120))
            throw new System.InvalidOperationException("Diagonal point inside safety range was rejected.");
        if (!NRO.Combat.MassacreAttackRange.RequiresServerMeleeRange(0)
            || !NRO.Combat.MassacreAttackRange.RequiresServerMeleeRange(2)
            || !NRO.Combat.MassacreAttackRange.RequiresServerMeleeRange(4)
            || !NRO.Combat.MassacreAttackRange.RequiresServerMeleeRange(17))
            throw new System.InvalidOperationException("Server-checked melee skills were not recognized.");
        if (NRO.Combat.MassacreAttackRange.RequiresServerMeleeRange(1)
            || !NRO.Combat.MassacreAttackRange.IsWithinSkillRange(1, 200, 0, 300, 100))
            throw new System.InvalidOperationException("Ranged skill was unnecessarily constrained to melee range.");
        if (NRO.Combat.MassacreAttackRange.IsWithinSkillRange(0, 80, 80, 120, 120))
            throw new System.InvalidOperationException("Melee diagonal outside server range was accepted.");
        if (!NRO.Combat.MassacreAttackRange.IsWithinSafeRange(30, 0, 30, 100))
            throw new System.InvalidOperationException("Valid close point was rejected.");
        if (NRO.Combat.MassacreAttackRange.IsWithinSafeRange(31, 0, 30, 100))
            throw new System.InvalidOperationException("Point outside skill X range was accepted.");
        if (NRO.Combat.MassacreAttackRange.GetApproachOffset(0, 300) != 80)
            throw new System.InvalidOperationException("Long-range skill did not use safe approach distance.");
        if (NRO.Combat.MassacreAttackRange.GetApproachOffset(0, 50) != 30)
            throw new System.InvalidOperationException("Approach distance exceeded a short skill range.");
        if (NRO.Combat.MassacreAttackRange.GetApproachOffset(1, 300) != 280)
            throw new System.InvalidOperationException("Ranged skill approach offset changed unexpectedly.");
        return "PASS massacre range: diagonal server bound, skill bounds, safe approach";
    }
}
'@
Add-Type -TypeDefinition ($helperSource + "`n" + $harness) -Language CSharp
[MassacreRangeRegression]::Run()
