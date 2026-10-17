$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
function Read-Block([string]$source, [string]$marker) {
    $start = $source.IndexOf($marker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing block: $marker" }
    $open = $source.IndexOf('{', $start)
    $depth = 1; $end = $open + 1
    while ($depth -gt 0 -and $end -lt $source.Length) {
        if ($source[$end] -eq '{') { $depth++ }
        if ($source[$end] -eq '}') { $depth-- }
        $end++
    }
    return $source.Substring($start, $end - $start)
}
foreach ($game in @('Game1','Game2')) {
    $character = Get-Content -LiteralPath "$clientRoot\Assets\Scripts\Assembly-CSharp\$game\Char.cs" -Raw
    $service = Get-Content -LiteralPath "$clientRoot\Assets\Scripts\Assembly-CSharp\$game\Service.cs" -Raw
    $startTeleport = Read-Block $character 'if (skillPaint.id >= 128 && skillPaint.id <= 134)'
    $attackGate = Read-Block $character 'if ((cx != cxSend || cy != cySend) && !Service.gI().TryCharMove())'
    $move = Read-Block $service 'public bool TryCharMove()'
    $cut = $move.IndexOf('long previousMp')
    if ($cut -lt 0) { throw 'Cannot locate movement guard boundary' }
    # Keep the actual guards, replace the network send body with a packet counter.
    $move = $move.Substring(0,$cut) + 'MovementPackets++; Char.myCharz().cxSend = Char.myCharz().cx; Char.myCharz().cySend = Char.myCharz().cy; return true; }'
    $update = Read-Block $character 'if (isSetPos)'
    $reply = Read-Block $update 'if (typePos == 1)'
    $harness = @'
using System;
namespace NAMESPACE {
    public class SkillPaint { public int id; }
    public class Mob { public int x, y; }
    public static class Controller { public static bool isStopReadMessage; }
    public static class GameScr {
        public static SkillPaint[] sks = new SkillPaint[200];
        static GameScr() { for (int i = 0; i < sks.Length; i++) sks[i] = new SkillPaint { id = i }; }
    }
    public static class ServerEffect { public static void addServerEffect(int id, int x, int y, int loops) { } }
    public class Service {
        public int MovementPackets;
        static Service self = new Service(); public static Service gI() { return self; }
        public bool IsCombatConnectionReady() { return true; }
        MOVE_GUARD
    }
    public class Char {
        static Char player; public static Char myCharz() { return player; }
        public static bool ischangingMap;
        public int cx = 100, cy = 100, cxSend = 100, cySend = 100, AttackPackets;
        public bool me = true, isTeleport, telePortSkill;
        public object currentMovePoint;
        public Char charFocus; public Mob mobFocus;
        public void Start(SkillPaint skillPaint) { TELEPORT_START }
        public void Attack() { ATTACK_GATE AttackPackets++; }
        public void ServerReply(int x, int y) { cx = x; cy = y; int typePos = 1; REPLY_BLOCK }
        static void Require(bool ok, string message) { if (!ok) throw new Exception(message); }
        public static string Run() {
            int cases = 0;
            for (int paint = 128; paint <= 134; paint++) {
                foreach (bool pvp in new bool[] { false, true }) {
                    foreach (int[] destination in new int[][] { new int[] {400,100}, new int[] {100,150}, new int[] {100,100} }) {
                        player = new Char(); Service.gI().MovementPackets = 0;
                        if (pvp) player.charFocus = new Char { cx = destination[0], cy = destination[1] };
                        else player.mobFocus = new Mob { x = destination[0], y = destination[1] };
                        player.Start(new SkillPaint { id = paint });
                        Require(player.cx == 100 && player.cy == 100 && !player.telePortSkill,
                            "Local DCTT must not predict coordinates or lock movement before server response");
                        player.Attack();
                        Require(player.AttackPackets == 1 && Service.gI().MovementPackets == 0,
                            "DCTT must send its attack from the authoritative origin");
                        // Delayed response does not hold normal movement hostage.
                        player.cx = 120;
                        Require(Service.gI().TryCharMove(), "Delayed response blocked real movement");
                        player.ServerReply(destination[0], destination[1]);
                        Require(!player.telePortSkill && player.cxSend == destination[0] && player.cySend == destination[1],
                            "Server response must synchronize destination coordinates");
                        player.cx = 900;
                        Require(Service.gI().TryCharMove() && player.cxSend == 900,
                            "Movement toward the next map must reach the server after DCTT");
                        cases++;
                        player = new Char { me = false, mobFocus = new Mob { x = destination[0], y = destination[1] } };
                        player.Start(new SkillPaint { id = paint });
                        Require(player.telePortSkill && player.cx == destination[0] && player.cy == destination[1],
                            "Remote DCTT visuals must preserve their existing prediction");
                        player.ServerReply(destination[0], destination[1]);
                        Require(!player.telePortSkill, "Remote server position must release its visual latch");
                        cases++;
                    }
                }
            }
            // No server reply (e.g. send failure/rejection) must not leave local prediction behind.
            player = new Char { mobFocus = new Mob { x = 400, y = 100 } };
            player.Start(new SkillPaint { id = 128 }); player.cx = 150;
            Require(!player.telePortSkill && Service.gI().TryCharMove(), "Absent response left a stuck local teleport latch");
            cases++;
            player = new Char { cx = 130 }; Service.gI().MovementPackets = 0; player.Attack();
            Require(player.AttackPackets == 1 && Service.gI().MovementPackets == 1, "Ordinary movement plus attack control failed");
            cases++;
            return "PASS " + cases + " cases: 7 levels, mob/player, X/Y/equal positions, remote visuals, delayed/absent replies and subsequent movement.";
        }
    }
}
'@
    $harness = $harness.Replace('NAMESPACE',"DcttAudit_$game").Replace('MOVE_GUARD',$move).Replace('TELEPORT_START',$startTeleport).Replace('ATTACK_GATE',$attackGate).Replace('REPLY_BLOCK',$reply)
    Add-Type -TypeDefinition $harness -Language CSharp
    $type = "DcttAudit_$game.Char" -as [type]
    Write-Output "$game : $($type.GetMethod('Run').Invoke($null,@()))"
}
