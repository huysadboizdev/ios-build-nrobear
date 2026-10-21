param([ValidateSet('Game1', 'Game2')][string]$Client = 'Game2')
$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot "../Assets/Scripts/Assembly-CSharp/$Client/Char.cs"
$source = [IO.File]::ReadAllText($sourcePath)
$start = $source.IndexOf('public void setSkillPaint(SkillPaint skillPaint, int sType)')
$end = $source.IndexOf('public void useSkillNotFocus()', $start)
if ($start -lt 0 -or $end -lt 0) { throw 'Cannot locate production setSkillPaint method' }
$method = $source.Substring($start, $end - $start)
$specialStart = $source.IndexOf('public void SetSkillPaint_NEW(')
$specialEnd = $source.IndexOf('public void UpdSkillPaint_NEW()', $specialStart)
if ($specialStart -lt 0 -or $specialEnd -lt 0) { throw 'Cannot locate production special skill methods' }
$specialMethods = $source.Substring($specialStart, $specialEnd - $specialStart)

# Execute the production method in memory. Rendering and transport are observed at
# their boundaries; no Unity player, APK, EXE or application JAR is produced.
$harness = @'
using System;
using System.Collections.Generic;
namespace PetAnimationRegression {
public class SkillPaint { public int id; }
public class Template { public int id, type = 1, manaUseType; }
public class Skill { public Template template = new Template(); public int coolDown = 1000, manaUse = 10; public long lastTimeUseThisSkill; public bool paintCanNotUseSkill; }
public class Mob { public int status = 2, holdEffID, x, y; }
public class Point { public int x, y; }
public static class GameCanvas { public static long timeNow = 10000; }
public static class TileMap { public static bool offline; public static bool isOfflineMap() { return offline; } }
public static class mSystem { public static long currentTimeMillis() { return 10000; } }
public class GameScr {
 public static SkillPaint[] sks = MakePaints();
 static SkillPaint[] MakePaints() { var p = new SkillPaint[200]; for(int i=0;i<p.Length;i++) p[i]=new SkillPaint {id=i}; return p; }
 static GameScr instance = new GameScr(); public static GameScr gI() { return instance; }
 public int auto, twMp; public bool isInjureMp, isUseFreez;
 public static List<int> effects = new List<int>();
 public static void addEffectEnd_Target(int id,int state,int paint,Char actor,Point target,int layer,int duration,int range,int level) { effects.Add(id); }
 public static void addEffectEnd(int id,int item,int paint,int x,int y,int layer,int state,int duration,Point[] targets,int level) { effects.Add(id); }
}
public class SoundMn {
 static SoundMn instance = new SoundMn(); public static SoundMn gI() { return instance; }
 public void hoisinh() {} public void thaiduonghasan() {} public void taitaoPause() {} public void gong() {}
}
public class Service {
 static Service instance = new Service(); public static Service gI() { return instance; }
 public static int sends; public void skill_not_focus(int id) { sends++; }
}
public static class ServerEffect { public static void addServerEffect(int a,int b,int c,int d) {} }
public class Effect { public Effect(int a,int b,int c,int d,int e,int f) {} }
public static class EffecMn { public static void addEff(Effect effect) {} }
public class Char {
 public bool me, finishingCharge, isStandAndCharge, isFlyAndCharge, isWaitMonkey, isUseSkillAfterCharge, stone, sleepEff, blindEff, isCharge, isCreateDark, telePortSkill, hasSendAttack;
 public Skill myskill; public Mob mobFocus; public Char charFocus;
 public object dart, currentMovePoint; public int statusMe, holdEffID, isMonkey, cx, cy, ch, chargeCount, cStamina = 100;
 public long cHP = 1000, cHPFull = 1000, cMP = 1000, cMPFull = 1000, last, cur, skillPaintManaSpent;
 public int skillPaintStaminaSpent, painted = -1, paintedType = -1;
 public bool isPaintNewSkill, isFly; public long timeReset_newSkill, timeDame;
 public short idskillPaint, rangeDame; public sbyte typeFrame, typePaint, typeItem;
 public int cdir, count_NEW, stt; public byte[] fr_start, fr_atk, fr_end; public Point targetDame;
 static Char local; public static Char myCharz() { return local; }
 public void stopUseChargeSkill() {} public bool isSelectingSkillBuffToPlayer() { return false; }
 public void cancelPendingManualMobRetry() {} public void beginChargeTiming() {} public void useChargeSkill(bool isGround) {}
 public void saveLoadPreviousSkill() {} public Char clone() { return this; }
 public void setAutoSkillPaint(SkillPaint paint,int type) { painted=paint.id; paintedType=type; }
__PRODUCTION_METHOD__
__SPECIAL_METHODS__
 public static string Run() {
  var failures = new List<string>(); int passed=0;
  Action<string,Action> check = (name,test) => { try { test(); passed++; } catch(Exception e) { failures.Add(name+": "+e.Message); } };
  // Pet actors arrive with an ID and appearance, without the local selected skill.
  foreach(string pet in new [] {"Normal","Mabu","Uub","Beerus","Jiren"}) {
   foreach(bool offline in new [] {false,true}) foreach(int paintId in new [] {0,7,14,21,28,35,63,107,128,164,165}) foreach(int stance in new [] {0,1}) {
    string name=pet+" offline="+offline+" paint="+paintId+" stance="+stance;
    check(name, () => {
     TileMap.offline=offline; Service.sends=0;
     var actor=new Char {mobFocus=new Mob(), dart=new object()};
     actor.setSkillPaint(GameScr.sks[paintId],stance);
     int expected=paintId==165 ? 106 : paintId>=128 && paintId<=134 ? paintId-65 : paintId>=107 && paintId<=113 ? paintId-44 : paintId;
     if(actor.painted!=expected || actor.paintedType!=stance) throw new Exception("server animation did not reach renderer");
     if(actor.cMP!=1000 || actor.cStamina!=100 || Service.sends!=0) throw new Exception("remote actor changed local combat state");
    });
   }
  }
  check("stone still blocks remote animation", () => {
   TileMap.offline=false; var actor=new Char {stone=true}; actor.setSkillPaint(GameScr.sks[0],0);
   if(actor.painted!=-1) throw new Exception("stone actor animated");
  });
  check("local offline map remains blocked", () => {
   TileMap.offline=true; local=new Char {me=true,myskill=new Skill()}; local.setSkillPaint(GameScr.sks[0],0);
   if(local.painted!=-1 || local.cMP!=1000) throw new Exception("local offline attack changed");
  });
  check("local cooldown remains enforced", () => {
   TileMap.offline=false; local=new Char {me=true,myskill=new Skill {lastTimeUseThisSkill=9999}}; local.setSkillPaint(GameScr.sks[0],0);
   if(local.painted!=-1 || !local.myskill.paintCanNotUseSkill || local.cMP!=1000) throw new Exception("cooldown bypassed");
  });
  check("local dart still blocks attack", () => {
   TileMap.offline=false; local=new Char {me=true,myskill=new Skill(),dart=new object()}; local.setSkillPaint(GameScr.sks[0],0);
   if(local.painted!=-1 || local.cMP!=1000) throw new Exception("dart guard bypassed");
  });
  check("local attack still spends mana and stamina", () => {
   TileMap.offline=false; local=new Char {me=true,myskill=new Skill()}; local.setSkillPaint(GameScr.sks[0],0);
   if(local.painted!=0 || local.cMP!=990 || local.cStamina!=99) throw new Exception("local attack changed");
  });
  foreach(string pet in new [] {"Uub","Beerus","Jiren"}) foreach(short id in new short [] {24,25,26}) foreach(bool fly in new [] {false,true}) foreach(sbyte paint in new sbyte [] {0,1,2,3}) {
   check(pet+" special="+id+" fly="+fly+" paint="+paint, () => {
    TileMap.offline=true; GameScr.effects.Clear(); Service.sends=0;
    var actor=new Char(); sbyte frame=(sbyte)(id-23);
    actor.SetSkillPaint_NEW(id,fly,frame,paint,1,2000,0,-1);
    if(!actor.isPaintNewSkill || actor.idskillPaint!=id || actor.fr_start==null || actor.fr_atk==null || actor.fr_end==null || GameScr.effects.Count!=2)
     throw new Exception("special charge animation not initialized");
    actor.SetSkillPaint_STT(1,id,new Point {x=100,y=100},3000,100,paint,new Point[0],0,-1);
    if(actor.stt!=1 || actor.idskillPaint!=id || GameScr.effects.Count!=4)
     throw new Exception("special release effects not initialized");
    if(actor.cMP!=1000 || actor.cStamina!=100 || Service.sends!=0) throw new Exception("remote special changed local combat state");
   });
  }
  if(failures.Count>0) throw new Exception(failures.Count+" failed, "+passed+" passed. First failures: "+string.Join("; ",failures.GetRange(0,Math.Min(6,failures.Count)).ToArray()));
  return "PASS "+passed+" checks: remote animation, offline maps, remaps, stance, special charge/release, local cooldown/mana/stamina guards";
 }
}
}
namespace NRO.Combat { public static class MobAttackResultTracker { public static bool CanAttemptFor(int a,byte b,long c) { return true; } } }
'@
Add-Type -TypeDefinition $harness.Replace('__PRODUCTION_METHOD__', $method).Replace('__SPECIAL_METHODS__', $specialMethods)
"${Client}: $([PetAnimationRegression.Char]::Run())"
