param([ValidateSet('Game1', 'Game2')][string]$Client = 'Game1')
$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "../Assets/Scripts/Assembly-CSharp/$Client/Mod/XMAP/PickMobController.cs"))
function Read-Method([string]$signature) {
    $start = $source.IndexOf($signature)
    if ($start -lt 0) { throw "Missing method $signature" }
    $open = $source.IndexOf('{', $start)
    $depth = 1
    $end = $open + 1
    while ($depth -gt 0 -and $end -lt $source.Length) {
        if ($source[$end] -eq '{') { $depth++ }
        if ($source[$end] -eq '}') { $depth-- }
        $end++
    }
    $source.Substring($start, $end - $start)
}
$methods = (Read-Method 'private static bool IsExcludedMassacreSkill(') + (Read-Method 'private static Skill GetSkillAttack(')
# Both automated attack paths must recheck the same rule before doing any work.
if ($source -notmatch 'if \(skill == null \|\| IsExcludedMassacreSkill\(skill\) \|\| !CanUseSkill\(skill, targetMob != null\)\) return false;') {
    throw 'Missing exclusion at automated attack dispatch'
}
$code = @'
using System;
using System.Collections.Generic;
public class SkillTemplate { public int id, type=4; }
public class Skill { public SkillTemplate template; }
public class MyVector : List<Skill> { public int size(){return Count;} public Skill elementAt(int i){return this[i];} }
public class Char { public MyVector vSkill=new MyVector(); static Char player=new Char(); public static Char myCharz(){return player;} }
public static class mSystem { public static long currentTimeMillis(){return 10000;} }
public static class MobAttackResultTracker { public static bool CanAttemptFor(int tab,byte skill,long now){return true;} }
public static class MassacreSkillTests {
 static int massacreSkillCursor;
 static bool CanUseSkill(Skill s,bool target) { return true; }
__METHODS__
 static void Check(bool condition,string name){if(!condition)throw new Exception(name);}
 static Skill Make(int id){return new Skill {template=new SkillTemplate {id=id}};}
 public static string Run(){
  int checks=0;
  var excluded=new HashSet<int>{7,10,11,14,24,25,26};
  for(int id=0;id<=28;id++){Check(IsExcludedMassacreSkill(Make(id))==excluded.Contains(id),"wrong exclusion for template "+id);checks++;}
  Check(IsExcludedMassacreSkill(null),"null skill must be skipped");checks++;
  Check(IsExcludedMassacreSkill(new Skill()),"null template must be skipped");checks++;
  foreach(bool mobTarget in new[]{true,false}){
   var skills=Char.myCharz().vSkill; skills.Clear(); skills.Add(Make(24));skills.Add(Make(25));skills.Add(Make(26));
   for(int cursor=0;cursor<3;cursor++){massacreSkillCursor=cursor;Check(GetSkillAttack(mobTarget)==null,"special-only list must not attack");checks++;}
   var regular=Make(1);regular.template.type=1;skills.Add(regular);
   for(int cursor=0;cursor<4;cursor++){massacreSkillCursor=cursor;Check(GetSkillAttack(mobTarget)==regular,"must skip special skills and find regular attack");checks++;}
   skills.Clear(); foreach(int id in excluded)skills.Add(Make(id));
   massacreSkillCursor=0;Check(GetSkillAttack(mobTarget)==null,"all excluded list must not attack");checks++;
   skills.Clear();skills.Add(null);skills.Add(new Skill());skills.Add(regular);
   Check(GetSkillAttack(mobTarget)==regular,"invalid entries must not prevent regular attack");checks++;
   skills.Clear();Check(GetSkillAttack(mobTarget)==null,"empty skills must not attack");checks++;
  }
  return "PASS "+checks+" checks: template exclusions, monster/player targeting, cursor rotation, regular fallback, invalid entries";
 }
}
'@
Add-Type -TypeDefinition $code.Replace('__METHODS__', $methods)
"${Client}: $([MassacreSkillTests]::Run())"
