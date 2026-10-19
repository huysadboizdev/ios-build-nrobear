param([string]$AdditionalClientRoot)
$ErrorActionPreference = 'Stop'
function Read-Block([string]$source, [string]$marker) {
    $start = $source.IndexOf($marker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing source block: $marker" }
    $open = $source.IndexOf('{', $start); $depth = 1; $end = $open + 1
    while ($depth -gt 0 -and $end -lt $source.Length) {
        if ($source[$end] -eq '{') { $depth++ }
        if ($source[$end] -eq '}') { $depth-- }
        $end++
    }
    return $source.Substring($start, $end - $start)
}
$roots = @((Split-Path -Parent $PSScriptRoot))
if ($AdditionalClientRoot) { $roots += $AdditionalClientRoot }
$allFailures = 0
for ($platform = 0; $platform -lt $roots.Count; $platform++) {
    foreach ($game in @('Game1','Game2')) {
        $source = [IO.File]::ReadAllText((Join-Path $roots[$platform] "Assets/Scripts/Assembly-CSharp/$game/Char.cs"))
        $setPos = Read-Block $source 'public void setPos(short xPos, short yPos, sbyte typePos)'
        $applyPos = Read-Block $source 'if (isSetPos)'
        $start = Read-Block $source 'if (skillPaint.id >= 128 && skillPaint.id <= 134)'
        $harness = @'
using System;
namespace NAMESPACE {
 public class Panel {
  public bool isShow;
  public int Hides;
  public void hide() { Hides++; isShow=false; GameCanvas.CleanupCalls++; }
 }
 public static class GameCanvas { public static Panel panel, panel2; public static int CleanupCalls; }
 public static class ServerEffect { public static int Calls; public static void addServerEffect(int id,int x,int y,int count){Calls++;} }
 public static class TileMap { public static bool Ground=true; public static int tileTypeAtPixel(int x,int y){return Ground?2:0;} }
 public class SkillPaint { public int id; }
 public class Mob { public int x,y; }
 public static class GameScr {
  public static SkillPaint[] sks=new SkillPaint[200];
  static GameScr(){for(int i=0;i<sks.Length;i++)sks[i]=new SkillPaint{id=i};}
 }
 public class Char {
  public bool me=true,isSetPos,telePortSkill;
  public int cx,cy,cxSend,cySend,tpos,cp1,cp2,cp3,statusMe=1;
  public short xPos,yPos; public sbyte typePos;
  public object currentMovePoint;
  public Char charFocus; public Mob mobFocus;
  SET_POS
  public void Start(SkillPaint skillPaint){TELEPORT_START}
  public void Tick(){APPLY_POS}
  static int checks,failures;
  static void Check(bool ok,string message){checks++;if(!ok){failures++;Console.WriteLine("FAIL "+message);}}
  public static int Run(){
   GameCanvas.panel=new Panel();GameCanvas.panel2=new Panel();GameCanvas.CleanupCalls=0;
   var actor=new Char();
   for(int i=0;i<1000;i++){actor.setPos((short)(100+i%500),408,1);actor.Tick();}
   Check(GameCanvas.CleanupCalls==0,"1000 casts with closed panels caused "+GameCanvas.CleanupCalls+" panel cleanup/forced-GC calls");
   Check(actor.cx==599&&actor.cy==408&&actor.cxSend==599&&actor.cySend==408,"stress final authoritative position and sent-position baseline");
   GameCanvas.panel=new Panel{isShow=true};GameCanvas.panel2=new Panel{isShow=true};GameCanvas.CleanupCalls=0;
   for(int i=0;i<1000;i++){actor.setPos(200,408,1);actor.Tick();}
   Check(GameCanvas.panel.Hides==1&&GameCanvas.panel2.Hides==1,"each visible panel must close once, rather than on every cast");
   Check(GameCanvas.CleanupCalls==2,"open panels produce exactly two cleanups across 1000 casts");
   foreach(bool ground in new[]{true,false})foreach(int dead in new[]{5,14}){
    TileMap.Ground=ground;actor=new Char();actor.setPos(300,200,1);actor.statusMe=dead;actor.telePortSkill=true;actor.Tick();
    Check(actor.statusMe==dead,"queued position overwrote death state "+dead+" ground="+ground);
    Check(!actor.telePortSkill&&!actor.isSetPos,"death interleave retains no teleport latch");
   }
   foreach(bool ground in new[]{true,false}){
    TileMap.Ground=ground;actor=new Char{telePortSkill=true,currentMovePoint=new object()};actor.setPos(123,240,1);actor.Tick();
    Check(actor.statusMe==(ground?1:4),"live character terrain status");
    Check(!actor.telePortSkill&&actor.currentMovePoint==null&&actor.cxSend==123,"valid reply releases movement latch");
   }
   GameCanvas.panel=null;GameCanvas.panel2=null;actor=new Char();actor.setPos(55,66,1);actor.Tick();
   Check(actor.cx==55&&actor.cy==66,"missing panels still apply position");
   GameCanvas.panel=new Panel();GameCanvas.panel2=new Panel();actor=new Char{me=false};actor.setPos(77,88,1);actor.Tick();
   Check(GameCanvas.panel.Hides==0&&GameCanvas.panel2.Hides==0,"remote position must not close local UI");
   for(int paint=128;paint<=134;paint++)foreach(bool pvp in new[]{true,false}){
    actor=new Char{cx=100,cy=100};
    if(pvp)actor.charFocus=new Char{cx=400,cy=200};else actor.mobFocus=new Mob{x=400,y=200};
    actor.Start(new SkillPaint{id=paint});
    Check(actor.cx==100&&actor.cy==100&&!actor.telePortSkill,"local teleport must wait for server coordinates without locking outgoing movement; paint="+paint+" pvp="+pvp);
    actor.me=false;actor.Start(new SkillPaint{id=paint});
    Check(actor.cx==400&&actor.cy==200&&actor.telePortSkill,"remote teleport retains predicted visual; paint="+paint);
   }
   Console.WriteLine("RESULT "+checks+" checks, "+failures+" failures");return failures;
  }
 }
}
'@
        $namespace = "DcttFreeze_${platform}_${game}"
        $harness = $harness.Replace('NAMESPACE',$namespace).Replace('SET_POS',$setPos).Replace('APPLY_POS',$applyPos).Replace('TELEPORT_START',$start)
        Add-Type -TypeDefinition $harness -Language CSharp
        $type = "$namespace.Char" -as [type]
        Write-Output "CLIENT $($roots[$platform]) $game"
        $allFailures += $type.GetMethod('Run').Invoke($null,@())
    }
}
if ($allFailures -gt 0) { throw "Instant transmission freeze regression: $allFailures failures" }
'PASS instant transmission repeated position/death/visible-panel regression for all supplied clients.'
