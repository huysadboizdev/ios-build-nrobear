"""Run actual allocation methods in memory; no client build or executable output."""
from pathlib import Path
import subprocess
import tempfile

NATIVE = Path(__file__).resolve().parents[1]
WEB = NATIVE.parent / 'nroteam/Teamobi2026/ClientWeb/PRJ_2Tab_Web'

SHELL = r'''
using System;
using System.Threading;
// Each game namespace defines Math, which hides System.Math in the real client.
class Math {}
namespace UnityEngine { public class WaitForSecondsRealtime { public WaitForSecondsRealtime(float n){} } }
namespace NroWeb { public class BrowserHost {
 public static System.Collections.IEnumerator worker;
 public static void Run(System.Collections.IEnumerator w){worker=w;}
} }
class Char {
 public long cHPGoc=1000,cMPGoc=1000,cDamGoc=1000,cDefGoc=1000,cTiemNang=1000000;
 public int cCriticalGoc=1;
 public static Char me=new Char(),pet=new Char();
 public static Char myCharz(){return me;} public static Char myPetz(){return pet;}
}
class Info { public int count; public string last; public void addInfo(string s,int n){count++;last=s;} }
class GameScr { public static Info info1=new Info(); }
class GameCanvas { public static int dialogs; public static void startOKDlg(string s){dialogs++;} }
class NoticeController {
 public void OK(string text7){ OKNOTICE }
 public void Toast(string itemNotice){ TOASTNOTICE }
}
class mSystem { public static long now; public static long currentTimeMillis(){return now;} }
class Service {
 public static Service instance=new Service(); public static Service gI(){return instance;}
 public int calls,points,type; public bool pet;
 public void upPotential(bool p,int t,int n){calls++;points=n;type=t;pet=p;}
}
class ModFunc {
 public static int indexAutoPoint=-1,pointIncrease; public static bool autoPointForPet;
 public static string[] strPointTypes={"HP","KI","SD","Giap","CM"};
 METHODS
 public int Begin(int type,int target,bool pet){
  indexAutoPoint=type;pointIncrease=target;autoPointForPet=pet;
  autoPointWaiting=false;return ++autoPointRunId;
 }
 public bool Step(int id){return StepAutoIncreasePoint(id);}
}
public class AutoPointTests {
 static void Check(bool ok,string why){if(!ok)throw new Exception(why);}
 static ModFunc Fresh(){Char.me=new Char();Char.pet=new Char();GameScr.info1=new Info();Service.instance=new Service();mSystem.now=0;return new ModFunc();}
 public static void Run(){
  ModFunc m=Fresh();int id=m.Begin(0,1019,false);
  Check(!m.Step(id)&&Service.instance.calls==0&&GameScr.info1.count==1,"near HP target must finish without overshoot");
  Check(!m.Step(id)&&GameScr.info1.count==1,"completion once");
  m=Fresh();id=m.Begin(1,1060,false);Check(m.Step(id)&&Service.instance.points==3,"KI remainder batch");
  mSystem.now=500;Check(m.Step(id)&&Service.instance.calls==1,"wait for server, no duplicate packets");
  Char.me.cMPGoc=1060;Check(!m.Step(id)&&Service.instance.calls==1,"stop after acknowledged target");
  m=Fresh();id=m.Begin(2,1027,false);Check(m.Step(id)&&Service.instance.points==27,"damage remainder batch");
  m=Fresh();id=m.Begin(0,999999,false);Check(m.Step(id)&&Service.instance.points==100,"normal HP batch");
  Char.me.cHPGoc=3000;mSystem.now=500;Check(m.Step(id)&&Service.instance.calls==2,"acknowledged progress continues");
  foreach(int type in new int[]{3,4}){m=Fresh();id=m.Begin(type,2000,false);m.Step(id);Check(Service.instance.points==1,"defense/critical single point");}
  m=Fresh();id=m.Begin(2,1000,false);Check(!m.Step(id)&&Service.instance.calls==0,"exact target");
  m=Fresh();id=m.Begin(0,2000,true);m.Step(id);Check(Service.instance.pet,"pet routing");
  mSystem.now=4999;Check(m.Step(id)&&Service.instance.calls==1,"slow response must not report cap");
  mSystem.now=5000;Check(!m.Step(id)&&Service.instance.calls==1&&GameScr.info1.last.Contains("phản hồi"),"unacknowledged request timeout stops honestly");
  m=Fresh();id=m.Begin(0,2000,true);Char.pet=null;Check(!m.Step(id)&&Service.instance.calls==0,"missing pet");
  m=Fresh();id=m.Begin(0,2000,false);Char.me.cTiemNang=0;Check(!m.Step(id)&&Service.instance.calls==0,"no potential");
  m=Fresh();id=m.Begin(0,2000,false);int next=m.Begin(2,2000,false);Check(!m.Step(id)&&Service.instance.calls==0,"old worker cancelled");Check(m.Step(next),"new worker active");
  Check(ModFunc.OnAutoPointNotice("Vui lòng mở giới hạn sức mạnh"),"server limit handled");
  Check(ModFunc.indexAutoPoint==-1&&ModFunc.pointIncrease==0&&!ModFunc.autoPointForPet,"state reset");
  int count=GameScr.info1.count;Check(!ModFunc.OnAutoPointNotice("Vui lòng mở giới hạn sức mạnh")&&GameScr.info1.count==count,"inactive limit untouched");
  m=Fresh();id=m.Begin(0,2000,false);Check(!ModFunc.OnAutoPointNotice("")&&!ModFunc.OnAutoPointNotice("Thông báo khác"),"unrelated notices untouched");
  Check(ModFunc.OnAutoPointNotice("Bạn không đủ tiềm năng")&&!m.Step(id),"insufficient potential stops");
  NoticeController controller=new NoticeController();GameCanvas.dialogs=0;
  m=Fresh();id=m.Begin(0,2000,false);controller.OK("Vui lòng mở giới hạn sức mạnh");
  Check(GameCanvas.dialogs==0&&GameScr.info1.count==1&&!m.Step(id),"limit dialog becomes one completion notice");
  controller.OK("Thông báo khác");Check(GameCanvas.dialogs==1,"unrelated dialog preserved");
  m=Fresh();id=m.Begin(0,2000,false);controller.Toast("Vui lòng mở giới hạn sức mạnh");
  Check(GameScr.info1.count==1&&!m.Step(id),"toast limit completes once");
  m=Fresh();id=m.Begin(0,2000,false);controller.Toast("Thông báo khác");
  Check(GameScr.info1.count==1&&ModFunc.indexAutoPoint==0,"unrelated toast preserved");
#if UNITY_WEBGL
  m=Fresh();ModFunc.indexAutoPoint=0;m.SetIncreasePoint("1040");
  Check(NroWeb.BrowserHost.worker.MoveNext()&&Service.instance.points==2,"browser driver sends bounded batch");
  Check(NroWeb.BrowserHost.worker.Current is UnityEngine.WaitForSecondsRealtime,"browser yields without blocking");
  Char.me.cHPGoc=1040;Check(!NroWeb.BrowserHost.worker.MoveNext()&&Service.instance.calls==1,"browser driver completes");
#endif
 }
}
'''

for root in (NATIVE, WEB):
    for game in ('Game1', 'Game2'):
        folder = root / 'Assets/Scripts/Assembly-CSharp' / game
        source = (folder / 'ModFunc.cs').read_text(encoding='utf-8-sig')
        assert 'private static int autoPointRunId' in source, f'{root.name}/{game}: bounded allocation worker missing'
        methods = source[source.index('private static int autoPointRunId'):source.index('public void LoadAcc()')]
        controller = (folder / 'Controller.cs').read_text(encoding='utf-8-sig')
        assert 'ModFunc.OnAutoPointNotice(text7)' in controller
        assert 'ModFunc.OnAutoPointNotice(itemNotice)' in controller
        assert 'while (StepAutoIncreasePoint(runId))' in methods
        if root == WEB:
            assert methods.count('while (StepAutoIncreasePoint(runId))') == 2
        ok_start = controller.index('if (!ModFunc.OnAutoPointNotice(text7))')
        ok_end = controller.index('InfoDlg.hide();', ok_start)
        toast_start = controller.index('if (!ModFunc.OnAutoPointNotice(itemNotice))')
        toast_end = controller.index('break;', toast_start)
        # Include only the existing notice dispatch statements, without case braces.
        toast = controller[toast_start:controller.index('GameScr.info1.addInfo(itemNotice, 0);', toast_start) + len('GameScr.info1.addInfo(itemNotice, 0);')]
        code = SHELL.replace('METHODS', methods).replace('OKNOTICE', controller[ok_start:ok_end]).replace('TOASTNOTICE', toast)
        for mode in (('desktop', 'browser') if root == WEB else ('desktop',)):
            with tempfile.TemporaryDirectory(prefix='auto-point-') as tmp:
                path = Path(tmp) / 'test.cs'
                path.write_text(code, encoding='utf-8-sig')
                options = ' -CompilerParameters $compiler' if mode == 'browser' else ''
                setup = "$compiler=New-Object System.CodeDom.Compiler.CompilerParameters; $compiler.GenerateInMemory=$true; $compiler.CompilerOptions='/define:UNITY_WEBGL'; " if mode == 'browser' else ''
                result = subprocess.run(['powershell', '-NoProfile', '-Command',
                    "$ErrorActionPreference='Stop'; " + setup + "Add-Type -Path '" + str(path) + "'" + options + "; [AutoPointTests]::Run()"],
                    capture_output=True, text=True, encoding='utf-8', errors='replace')
                assert result.returncode == 0, result.stdout + result.stderr
            print(f'PASS: {root.name}/{game}/{mode} allocation behavior and notice integration')
