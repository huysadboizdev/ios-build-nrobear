$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$controllers = @(
    'Assets/Scripts/Assembly-CSharp/Game1/Mod/XMAP/PickMobController.cs',
    'Assets/Scripts/Assembly-CSharp/Game2/Mod/XMAP/PickMobController.cs'
)

foreach ($relativePath in $controllers) {
    $source = Get-Content -LiteralPath (Join-Path $repo $relativePath) -Raw
    $method = [regex]::Match($source, 'private static bool CanStartMassacreSkill\(Char player\)\s*\{(?<body>[^}]+)\}')
    if (-not $method.Success) { throw "$relativePath is missing CanStartMassacreSkill." }
    $body = [regex]::Replace($method.Groups['body'].Value, '//[^\r\n]*', '')
    if ($body -match 'indexSkill|skillInfoPaint') {
        throw "$relativePath gates massacre attacks on the suppressed skill animation."
    }
    if ($body -notmatch 'player\s*!=\s*null') {
        throw "$relativePath does not guard against a missing player."
    }
    if ($body -match 'MobAttackResultTracker\.HasPending') {
        throw "$relativePath blocks the next massacre action while waiting for a server acknowledgment."
    }
    if ($source -notmatch 'ModFunc\.GI\(\)\.SetUsedSkill\(skill\)') {
        throw "$relativePath does not apply per-skill cooldown after a successful attack."
    }
    $castMethod = [regex]::Match($source, 'private static bool TryUseMassacreSkill\(Skill skill, Mob targetMob, Char targetChar\)\s*\{(?<body>.*?)\n\s*private static Skill GetSkillAttack2\(', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $castMethod.Success -or $castMethod.Groups['body'].Value -notmatch 'if\s*\(used\)\s*\{[^}]*SetUsedSkill\(skill\)') {
        throw "$relativePath must predict per-skill cooldown when the cast is queued successfully."
    }
    if ($castMethod.Groups['body'].Value -match 'HasPendingSkillFor') {
        throw "$relativePath must not wait for network ACK before casting a ready skill."
    }
}

'PASS massacre can act while own skill animation is suppressed; queued casts retain per-skill cooldown without an ACK gate.'
