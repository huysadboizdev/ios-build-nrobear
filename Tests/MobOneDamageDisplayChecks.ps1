$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($game in @('Game1', 'Game2')) {
    $path = Join-Path $repo "Assets/Scripts/Assembly-CSharp/$game/Controller.cs"
    $source = [IO.File]::ReadAllText($path)
    $start = $source.IndexOf("case -9:", [StringComparison]::Ordinal)
    $end = $source.IndexOf("case -8:", $start, [StringComparison]::Ordinal)
    if ($start -lt 0 -or $end -lt 0) { throw "Cannot isolate mob damage handler in $game" }
    $block = $source.Substring($start, $end - $start)

    if ($block -match 'if\s*\(num204\s*!=\s*1\)') {
        $failures.Add("$game still drops all handling when mob damage equals one.")
    }
    if ($block -notmatch 'if\s*\(num204\s*>\s*0\)\s*\{\s*mob14\.setInjure\(\);') {
        $failures.Add("$game must animate every positive mob hit, including one damage.")
    }
    if ($block -notmatch 'else if\s*\(num204\s*>\s*0\)\s*\{\s*GameScr\.startFlyText\("-"\s*\+\s*num204') {
        $failures.Add("$game must show a damage number for every positive mob hit, including one damage.")
    }
    if ($block -notmatch 'num204\s*==\s*0L') {
        $failures.Add("$game must retain the existing miss feedback for zero damage.")
    }
}

if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
Write-Output 'PASS both client lanes animate and display one-damage mob hits; zero-damage miss feedback remains.'
