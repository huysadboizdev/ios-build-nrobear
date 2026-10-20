"""Exercise actual batch/recipe/menu methods extracted from both client panels."""
import sys
sys.dont_write_bytecode = True
import pathlib
import subprocess
import tempfile
from UpgradeX100Checks import block, SOURCE

METHODS = ["private bool IsUpgradeCombineRecipe()", "private bool HasUpgradeProtectionRequirement()",
           "private void EnsureUpgradeProtectionSelected()",
           "private bool IsProtectionStone(Item item)", "private int CountUpgradeProtectionStones()",
           "private string GetUpgradeBatchItemSignature()", "private MyVector GetUpgradeBatchItems()",
           "private void StartUpgradeBatch()", "private void SendNextUpgradeBatchAttempt()",
           "public void HandleUpgradeBatchResponse(bool successful)", "private void ContinueUpgradeBatchAfterEffect()",
           "private void CancelUpgradeBatch()", "public void CancelUpgradeBatchFromServerSelection()",
           "public bool HandleUpgradeBatchMenu(int npcId, string text, string[] captions)"]
SHELL = r'''
using System;
using System.Collections.Generic;
class ItemTemplate { public int id,type; }
class Item { public ItemTemplate template; public int quantity,indexUI; public bool isSelect; }
class MyVector { public List<object> list=new List<object>(); public int size(){return list.Count;} public object elementAt(int n){return list[n];} public void addElement(object o){list.Add(o);} }
class Char { public Item[] arrItemBag; static Char me=new Char(); public static Char myCharz(){return me;} }
class Session_ME { public static Session_ME gI(){return new Session_ME();} public bool isConnected(){return true;} }
class ModFunc { public bool isAutoPhaLe; public static ModFunc GI(){return new ModFunc();} }
class Service { public static Service me=new Service(); public int sends,confirms; public static Service gI(){return me;} public bool combine(int n,MyVector items){sends++;return true;} public void confirmMenu(short npc,sbyte index){confirms++;} }
class mSystem { public static long currentTimeMillis(){return 10;} }
class InfoDlg { public static void showWait(){} public static void hide(){} }
class Info { public void addInfo(string s,int n){} }
class GameScr { public static Info info1=new Info(); }
class Command { public Command(string s,object o,int action,object data){} }
class Menu { public bool showMenu; public MyVector menuItems=new MyVector(); public void doCloseMenu(){} public void startAt(MyVector items,int n){} }
class GameCanvas { public static Menu menu=new Menu(); }
class ChatPopup { public static ChatPopup currChatPopup; }
class Panel {
 int type=12,currentTabIndex=0;
 bool isShow=true,isDoneCombine=true;
 MyVector vItemCombine=new MyVector();
 readonly UpgradeBatchState upgradeBatch=new UpgradeBatchState();
 bool upgradeBatchMode,upgradeBatchResponseDrainPending,upgradeMenuProtection,upgradeBatchAwaitingMenu;
 long upgradeBatchRequestTime;
 string upgradeBatchItemSignature=string.Empty;
 const int UPGRADE_BATCH_ATTEMPTS=100;
 METHODS
 static Item Make(int id,int type,int quantity,int slot){return new Item{template=new ItemTemplate{id=id,type=type},quantity=quantity,indexUI=slot};}
 static void Check(bool ok,string message){if(!ok)throw new Exception(message);}
 static Panel Setup(bool protection,int quantity){
   Service.me=new Service(); Panel p=new Panel();
   Item gear=Make(1,0,1,0),stone=Make(2,14,1000,1),guard=Make(987,99,quantity,2);
   p.vItemCombine.addElement(gear);p.vItemCombine.addElement(stone);
   if(protection)p.vItemCombine.addElement(guard);
   Char.myCharz().arrItemBag=new Item[]{gear,stone,guard};return p;
 }
 static string[] Captions(bool protection){return new[]{protection?"Nâng cấp\n10 vàng\nCần tốn 1 đá bảo vệ":"Nâng cấp\n10 vàng","Từ chối"};}
 public static void Main(){
   Panel auto=Setup(false,100);
   auto.EnsureUpgradeProtectionSelected();
   Check(auto.vItemCombine.size()==3 && auto.HasUpgradeProtectionRequirement(),"bag protection must appear without manual selection");
   auto.EnsureUpgradeProtectionSelected();Check(auto.vItemCombine.size()==3,"must not duplicate protection");
   auto.StartUpgradeBatch();
   Check(Service.me.sends==1,"auto-protected batch must start");
   Check(!auto.HandleUpgradeBatchMenu(21,"Sau khi nâng cấp",Captions(false)) && Service.me.confirms==0,"must never confirm unprotected menu for protected batch");
   Panel p=Setup(true,99);p.StartUpgradeBatch();Check(Service.me.sends==0,"99 protection stones must block");
   p=Setup(false,0);p.StartUpgradeBatch();Check(Service.me.sends==1,"no protection recipe must start");
   Check(p.HandleUpgradeBatchMenu(21,"Sau khi nâng cấp",Captions(false)),"expected menu must auto confirm");
   Check(Service.me.confirms==1,"one confirmation per attempt");
   p.HandleUpgradeBatchResponse(true);p.ContinueUpgradeBatchAfterEffect();Check(Service.me.sends==1,"success must stop");
   p=Setup(true,100);p.StartUpgradeBatch();
   for(int i=0;i<100;i++){
     Check(Service.me.sends==i+1,"sequential send count");
     Check(p.HandleUpgradeBatchMenu(21,"Sau khi nâng cấp",Captions(true)),"protected confirmation");
     p.HandleUpgradeBatchResponse(false);Char.myCharz().arrItemBag[2].quantity--;
     p.CancelUpgradeBatchFromServerSelection();
     Check(Service.me.sends==i+1,"failure must wait for effect");
     p.ContinueUpgradeBatchAfterEffect();
   }
   Check(Service.me.sends==100&&Service.me.confirms==100,"100 attempt cap");
   p=Setup(false,0);p.StartUpgradeBatch();Check(!p.HandleUpgradeBatchMenu(21,"Không đủ vàng",new[]{"Đóng"}),"invalid menu remains visible");
   Check(!p.upgradeBatchMode&&Service.me.confirms==0,"invalid menu must stop without confirm");
   p=Setup(false,0);p.StartUpgradeBatch();p.CancelUpgradeBatch();p.StartUpgradeBatch();Check(Service.me.sends==1,"cancelled pending result blocks restart");
   Console.WriteLine("PASS actual panel: protection 99/100, no protection, NPC confirmation, failure/effect/reopen, success stop, 100 limit, invalid menu, cancel");
 }
}
'''
for game in ("Game1", "Game2"):
    source = (SOURCE / game / "Panel.cs").read_text(encoding="utf-8-sig")
    with tempfile.TemporaryDirectory(prefix="upgrade-panel-") as directory:
        cs = pathlib.Path(directory) / "Harness.cs"
        exe = pathlib.Path(directory) / "Harness.exe"
        cs.write_text(SHELL.replace(" METHODS", "\n".join(block(source, marker) for marker in METHODS)), encoding="utf-8-sig")
        subprocess.run([r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe", "/nologo", "/warn:0", "/out:"+str(exe), str(cs), str(SOURCE / "UpgradeBatchState.cs")], check=True)
        subprocess.run([str(exe)], check=True)
