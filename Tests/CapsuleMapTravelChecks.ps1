param([string]$AdditionalClientRoot)
$ErrorActionPreference = 'Stop'

function Assert-Contains([string]$source, [string]$text, [string]$context) {
    if (-not $source.Contains($text)) { throw "FAIL $($context): missing '$text'" }
}
function Assert-NotContains([string]$source, [string]$text, [string]$context) {
    if ($source.Contains($text)) { throw "FAIL $($context): unexpected '$text'" }
}
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
$variantIndex = 0
foreach ($root in $roots) {
    foreach ($game in @('Game1','Game2')) {
        $xmapDir = Join-Path $root "Assets/Scripts/Assembly-CSharp/$game/Mod/XMAP"
        $controller = [IO.File]::ReadAllText((Join-Path $xmapDir 'XmapController.cs'))
        $data = [IO.File]::ReadAllText((Join-Path $xmapDir 'XmapData.cs'))
        $auto = [IO.File]::ReadAllText((Join-Path $xmapDir 'AutoXmap.cs'))
        $finish = Read-Block $controller 'public static void FinishXmap()'
        $update = Read-Block $controller 'public static void Update()'
        $selectionGate = Read-Block $update 'if (hasPendingCapsuleSelection)'
        $capsule = Read-Block $controller 'private static void NextMapCapsule(MapNext mapNext)'
        $dataUpdate = Read-Block $data 'public void Update()'
        $dataCancel = Read-Block $data 'public void CancelCapsuleLoading()'
        $infoMethod = Read-Block $auto 'public static void Info(string text)'
        Assert-Contains $finish 'GameCanvas.panel.isShow' "$root $game FinishXmap visibility guard"
        Assert-Contains $controller 'HasPendingCapsuleSelection' "$root $game pending selection state"
        Assert-Contains $update 'CapsuleSelectionTimeout' "$root $game bounded selection wait"
        Assert-Contains $selectionGate 'return;' "$root $game no route-step while capsule selection is pending"
        if ($update.IndexOf('if (hasPendingCapsuleSelection)') -gt $update.IndexOf('NextMap(WayXmap[IndexWay + 1])')) {
            throw "FAIL $root $game pending-selection gate runs after route request"
        }
        Assert-Contains $capsule 'BeginCapsuleSelection' "$root $game one-shot capsule selection"
        Assert-Contains $data 'CapsuleLoadTimeout' "$root $game capsule map-list timeout"
        Assert-Contains $dataUpdate 'CapsuleLoadTimeout' "$root $game map-list timeout processing"
        Assert-Contains $auto 'IsCapsuleLoading' "$root $game capsule failure classification"
        $harness = @'
using System;
using System.Collections.Generic;
namespace NAMESPACE {
 public static class AutoXmap { public static bool IsXmapRunning; }
 public class Panel { public bool isShow; public int hides; public void hide(){hides++;isShow=false;} }
 public static class GameCanvas { public static Panel panel; }
 public sealed class Data { public object MyLinkMaps; public int cancellations; public void CancelCapsuleLoading(){cancellations++;} }
 public static class XmapData { public static Data data=new Data(); public static Data GI(){return data;} }
 public static class XmapController {
  private static bool IsNextMapFailed;
  private static bool hasPendingCapsuleSelection;
  private static List<int> WayXmap;
  FINISH_METHOD
  static void Check(bool ok,string message){if(!ok)throw new Exception(message);}
  public static int Run(){
   int cases=0;
   foreach(bool visible in new[]{false,true}){
    GameCanvas.panel=new Panel{isShow=visible}; AutoXmap.IsXmapRunning=true;
    IsNextMapFailed=true; WayXmap=new List<int>{1}; XmapData.data.MyLinkMaps=new object();
    FinishXmap();
    Check(!AutoXmap.IsXmapRunning&&!IsNextMapFailed&&!hasPendingCapsuleSelection&&WayXmap==null,"XMAP state reset");
    Check(XmapData.data.MyLinkMaps==null&&XmapData.data.cancellations==cases+1,"capsule state reset");
    Check(GameCanvas.panel.hides==(visible?1:0),"panel hide count for visible="+visible);
    cases++;
   }
   GameCanvas.panel=null; FinishXmap(); cases++;
   return cases;
  }
 }
}
'@
        $namespace = 'CapsuleFinish_{0}_{1}' -f $variantIndex, $game
        $harness = $harness.Replace('NAMESPACE',$namespace).Replace('FINISH_METHOD',$finish)
        Add-Type -TypeDefinition $harness -Language CSharp
        $finishType = "$namespace.XmapController" -as [type]
        [void]$finishType.GetMethod('Run').Invoke($null,@())

        $dataHarness = @'
using System;
namespace NAMESPACE {
 public static class mSystem { public static long Now; public static long currentTimeMillis(){return Now;} }
 public static class AutoXmap { public static bool IsShowPanelMapTrans; public static bool CanRequestCapsuleMapList(){return true;} public static void IgnorePendingCapsulePanelResponse(){} }
 public static class XmapController { public static int finishes; public static void FinishXmap(){finishes++;} public static void UseCapsuleVip(){} public static void UseCapsuleNormal(){} }
 public static class GameScr { public static Info info1=new Info(); public class Info { public int notices; public void addInfo(string s,int type){notices++;} } }
 public class XmapData {
  private const long CapsuleLoadTimeout = 10000L;
  private bool IsLoadingCapsule;
  private long CapsuleLoadStartedAt;
  public bool IsLoading;
  public bool WaitForInfoMapTrans;
  public int CapsuleLoads;
  private bool IsWaitInfoMapTrans(){return WaitForInfoMapTrans;}
  private void LoadLinkMapCapsule(){CapsuleLoads++;}
  private void StartCapsuleLoading(){IsLoadingCapsule=true;}
  private void LoadLinkMapBase(){}
  private bool CanUseCapsuleVip(){return false;}
  private bool CanUseCapsuleNormal(){return false;}
  public void Prepare(bool pending,long started,bool wait){IsLoadingCapsule=pending;CapsuleLoadStartedAt=started;WaitForInfoMapTrans=wait;IsLoading=true;}
  DATA_CANCEL
  DATA_UPDATE
  static void Check(bool ok,string message){if(!ok)throw new Exception(message);}
  public static int Run(){
   XmapController.finishes=0;GameScr.info1.notices=0;AutoXmap.IsShowPanelMapTrans=false;
   var timeout=new XmapData();timeout.Prepare(true,100,true);mSystem.Now=10100;timeout.Update();
   Check(!timeout.IsLoading&&XmapController.finishes==1&&GameScr.info1.notices==1,"missing map-list response expires and stops XMAP");
   var success=new XmapData();success.Prepare(true,100,false);mSystem.Now=10100;success.Update();
   Check(!success.IsLoading&&success.CapsuleLoads==1&&XmapController.finishes==1,"map-list response completes without stopping XMAP");
   return 2;
  }
 }
}
'@
        $dataNamespace = 'CapsuleData_{0}_{1}' -f $variantIndex, $game
        $dataHarness = $dataHarness.Replace('NAMESPACE',$dataNamespace).Replace('DATA_CANCEL',$dataCancel).Replace('DATA_UPDATE',$dataUpdate)
        Add-Type -TypeDefinition $dataHarness -Language CSharp
        $dataType = "$dataNamespace.XmapData" -as [type]
        [void]$dataType.GetMethod('Run').Invoke($null,@())

        $infoHarness = @'
using System;
namespace NAMESPACE {
 public static class AutoXmap { public static bool IsXmapRunning; INFO_METHOD }
 public static class XmapData { public static Data data=new Data(); public static Data GI(){return data;} public class Data { public bool IsCapsuleLoading; } }
 public static class XmapController { public static bool HasPendingCapsuleSelection; public static int finishes; public static void FinishXmap(){finishes++;} }
 public static class Runner {
  static void Check(bool ok,string message){if(!ok)throw new Exception(message);}
  public static int Run(){
   string fullZone="Hi\u1ec7n t\u1ea1i kh\u00f4ng th\u1ec3 v\u00e0o \u0111\u01b0\u1ee3c khu!";
   if(!fullZone.ToLower().Contains("kh\u00f4ng th\u1ec3 v\u00e0o \u0111\u01b0\u1ee3c khu"))throw new Exception("test text does not contain full-zone notice");
   XmapData.data.IsCapsuleLoading=true;XmapController.HasPendingCapsuleSelection=true;XmapController.finishes=0;AutoXmap.Info(fullZone);
   Check(XmapController.finishes==1,"full-zone rejection terminates capsule XMAP count="+XmapController.finishes);
   XmapData.data.IsCapsuleLoading=false;XmapController.HasPendingCapsuleSelection=true;XmapController.finishes=0;AutoXmap.Info("Kh\u00f4ng th\u1ec3 mang ng\u1ecdc r\u1ed3ng n\u00e0y l\u00ean Phi thuy\u1ec1n");
   Check(XmapController.finishes==1,"capsule denial terminates pending selection");
   XmapController.HasPendingCapsuleSelection=false;XmapController.finishes=0;AutoXmap.Info("Unrelated notice");
   Check(XmapController.finishes==0,"unrelated notice preserves XMAP");
   XmapController.HasPendingCapsuleSelection=true;XmapController.finishes=0;AutoXmap.Info("Bạn chưa thể đến khu vực này");
   Check(XmapController.finishes==1,"exact inaccessible-area notice finishes XMAP exactly once");
   return 4;
  }
 }
}
'@
        $infoNamespace = 'CapsuleInfo_{0}_{1}' -f $variantIndex, $game
        $infoHarness = $infoHarness.Replace('NAMESPACE',$infoNamespace).Replace('INFO_METHOD',$infoMethod)
        Add-Type -TypeDefinition $infoHarness -Language CSharp
        $infoType = "$infoNamespace.Runner" -as [type]
        [void]$infoType.GetMethod('Run').Invoke($null,@())
        $variantIndex++
        Write-Output "PASS capsule XMAP state $root $game"
    }

    foreach ($game in @('Game1','Game2')) {
        $controllerPath = Join-Path $root "Assets/Scripts/Assembly-CSharp/$game/Controller.cs"
        if (-not (Test-Path $controllerPath)) { continue }
        $controller = [IO.File]::ReadAllText($controllerPath)
        $transition = Read-Block $controller 'case -24:'
        $mapTemplate = Read-Block $controller 'case 10:'
        $loadInfo = Read-Block $controller 'public void loadInfoMap(Message msg)'
        Assert-NotContains $transition 'mSystem.gcc();' "$root $game map transition"
        if ($mapTemplate.Contains('REQUEST MAP TEMPLATE')) {
            Assert-NotContains $mapTemplate 'mSystem.gcc();' "$root $game map-template response"
        }
        Assert-NotContains $loadInfo 'Resources.UnloadUnusedAssets();' "$root $game map load resource cleanup"
        Assert-NotContains $loadInfo 'GC.Collect();' "$root $game map load managed cleanup"
    }
}
Write-Output 'PASS capsule map travel source regressions for all supplied client variants.'
