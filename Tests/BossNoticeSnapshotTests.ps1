param([ValidateSet('Game1', 'Game2')][string]$Client = 'Game1')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$board = [IO.File]::ReadAllText((Join-Path $root "Assets/Scripts/Assembly-CSharp/$Client/BossNoticeBoard.cs"))
$data = [IO.File]::ReadAllText((Join-Path $root 'Assets/Scripts/BossNoticeData.cs'))
$code = @'
namespace __CLIENT__.Assets.src.g { internal class GameInfo {public short id;public string main,content;public bool hasRead;} }
namespace __CLIENT__ {
public class MyVector : System.Collections.ArrayList {public int size(){return Count;}public object elementAt(int i){return this[i];}public void addElement(object o){Add(o);}public void removeAllElements(){Clear();}}
public class Panel {public bool isShow=true;public int type=23;public int refreshes;public static MyVector vGameInfo=new MyVector();public void RefreshBossList(){refreshes++;}}
public static class GameCanvas {public static Panel panel=new Panel();}
public class Service {public static int requests;static Service instance=new Service();public static Service gI(){return instance;}public void bossNotices(int id,sbyte category,sbyte kind,int page,bool v2){requests++;}}
public class Reader {System.Collections.Generic.Queue<object> values;public Reader(object[] v){values=new System.Collections.Generic.Queue<object>(v);}public int readInt(){return System.Convert.ToInt32(values.Dequeue());}public int readUnsignedByte(){return readInt();}public int readUnsignedShort(){return readInt();}public short readShort(){return (short)readInt();}public sbyte readByte(){return (sbyte)readInt();}public long readLong(){return System.Convert.ToInt64(values.Dequeue());}public string readUTF(){return (string)values.Dequeue();}}
public class Message {Reader r;public Message(params object[] v){r=new Reader(v);}public Reader reader(){return r;}}
public static class SnapshotTests {
 const System.Reflection.BindingFlags flags=System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Public;
 static object Get(string n){return typeof(BossNoticeBoard).GetField(n,flags).GetValue(null);}
 static void Set(string n,object v){typeof(BossNoticeBoard).GetField(n,flags).SetValue(null,v);}
 static void Check(bool ok,string name){if(!ok)throw new System.Exception(name);}
 static Message Packet(int id,string name,bool push=false){
  var a=new System.Collections.Generic.List<object>();a.Add(push?-3:-2);if(!push)a.Add(id);a.Add(2);a.Add(0);a.Add(0);a.Add(1);if(push)a.Add(1L);
  a.Add(100000L);a.Add("");a.Add(1);
  foreach(string s in new[]{"spawn",name,"Map","","ALIVE"})a.Add(s);
  a.Add(90000L);a.Add(0L);a.Add(0L);a.Add("UNKNOWN");a.Add(2);a.Add(-20);a.Add(0);a.Add(-1);
  return new Message(a.ToArray());
 }
 public static string Run(){
  BossNoticeBoard.Reset();Service.requests=0;
  BossNoticeBoard.Reconnected();Check(Service.requests==0,"login must not preload boss rows");
  BossNoticeBoard.Select(-32751);Check(Service.requests==1,"explicit category click requests once");
  int id=(int)Get("pending");BossNoticeBoard.Receive(Packet(id,"first"));
  var entries=(System.Collections.Generic.List<BossNoticeEntry>)Get("entries");Check(entries.Count==1&&entries[0].Name=="first","request reply applies");
  int refreshes=GameCanvas.panel.refreshes;
  BossNoticeBoard.Receive(Packet(0,"unsolicited",true));
  Check(entries.Count==1&&entries[0].Name=="first"&&GameCanvas.panel.refreshes==refreshes,"push must not replace or rebuild current list");
  for(int i=0;i<30;i++)BossNoticeBoard.Tick(GameCanvas.panel);
  Check(Service.requests==1,"idle panel must not poll");
  Set("page",3);BossNoticeBoard.Opened();
  Check((int)Get("page")==0&&((System.Collections.Generic.List<BossNoticeEntry>)Get("entries")).Count==0,"reopen must clear stale rows and show newest page");
  Set("sent",0L);BossNoticeBoard.Tick(GameCanvas.panel);id=(int)Get("pending");
  BossNoticeBoard.Receive(Packet(id,"newest"));entries=(System.Collections.Generic.List<BossNoticeEntry>)Get("entries");
  Check(entries.Count==1&&entries[0].Name=="newest","reopen displays newest reply");
  int requests=Service.requests;BossNoticeBoard.Reconnected();
  Check(Service.requests==requests&&!(bool)Get("wants"),"reconnect must not auto-request a previously opened board");
  Set("pending",88);GameCanvas.panel.isShow=false;BossNoticeBoard.Receive(Packet(88,"closed"));
  Check(entries[0].Name=="newest","closed panel ignores late replies");
  GameCanvas.panel.isShow=true;BossNoticeBoard.Opened();int old=(int)Get("pending");BossNoticeBoard.Opened();
  Check(old==0||(int)Get("pending")!=old,"reopen abandons previous in-flight response");
  return "PASS: explicit load, no login/reconnect/push/poll refresh, latest page on reopen, stale/closed replies ignored";
 }
}
}
'@
$usings = "using System;`nusing System.Collections.Generic;`nusing System.Diagnostics;`nusing System.Text;`nusing $Client.Assets.src.g;`n"
$body = [regex]::Replace($board, '(?m)^using .*;\r?\n', '') + [regex]::Replace($data, '(?m)^using .*;\r?\n', '')
Add-Type -TypeDefinition ($usings + $body + $code.Replace('__CLIENT__',$Client))
$testType = "$Client.SnapshotTests" -as [type]
"${Client}: $($testType::Run())"
