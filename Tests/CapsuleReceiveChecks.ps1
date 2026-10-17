$ErrorActionPreference = 'Stop'
# Use an explicit source location as well when this script is run via Invoke-Expression.
$clientRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { 'C:\Users\Admin\Downloads\PRJ_2Tab_550K' }
$failures = @()
foreach ($game in @('Game1', 'Game2')) {
    foreach ($session in @('Session_ME', 'Session_ME2')) {
        $source = Get-Content -LiteralPath "$clientRoot\Assets\Scripts\Assembly-CSharp\$game\$session.cs" -Raw
        $field = [regex]::Match($source, 'public static (?:readonly )?[^\r\n]+ recieveMsg = [^\r\n]+;').Value
        $members = [regex]::Match($source, '(?s)(?:private const int MaxReceiveMessagesPerFrame|public static void onRecieveMsg).*?(?=\r?\n\t\tpublic void close\()').Value
        if (-not $field -or -not $members) { throw "Cannot extract production receive code: $game/$session" }
        $vector = Get-Content -LiteralPath "$clientRoot\Assets\Scripts\Assembly-CSharp\$game\MyVector.cs" -Raw
        $namespace = "CapsuleCheck_${game}_${session}"
        $vector = $vector.Replace("namespace $game", "namespace $namespace")
        $harness = @'
using System;
using System.Collections.Generic;
using System.Threading;
namespace NAMESPACE {
    public class Message { public int command; public Message(int c) { command = c; } }
    public static class Main { public static string mainThreadName = "collector-test"; }
    public static class Time { public static int frameCount; }
    public static class Controller { public static bool isStopReadMessage; }
    public class Handler {
        public List<int> received = new List<int>();
        public Action<Message> action;
        public void onMessage(Message message) { received.Add(message.command); if (action != null) action(message); }
    }
    public static class Pump {
        RECEIVE_FIELD
        public static Handler messageHandler;
        RECEIVE_MEMBERS
        static int Count() {
            var property = recieveMsg.GetType().GetProperty("Count");
            return property != null ? (int)property.GetValue(recieveMsg, null)
                : (int)recieveMsg.GetType().GetMethod("size").Invoke(recieveMsg, null);
        }
        static void Reset() {
            Main.mainThreadName = "collector-test";
            Controller.isStopReadMessage = false;
            Time.frameCount++;
            messageHandler = new Handler();
            var clear = recieveMsg.GetType().GetMethod("Clear") ?? recieveMsg.GetType().GetMethod("removeAllElements");
            clear.Invoke(recieveMsg, null);
        }
        static void Require(bool ok, string text) { if (!ok) throw new Exception(text); }
        static void Enqueue(int command) { onRecieveMsg(new Message(command)); }
        static void NextFrame() { Time.frameCount++; update(); }
        static void Drain() {
            for (int i = 0; i < 1000 && Count() > 0; i++) NextFrame();
            Require(Count() == 0, "Queue did not drain after resume");
        }
        static void Sequence(params int[] expected) {
            Require(messageHandler.received.Count == expected.Length, "Unexpected packet count");
            for (int i = 0; i < expected.Length; i++)
                Require(messageHandler.received[i] == expected[i], "FIFO order changed at " + i);
        }
        static void CapsulePauseResume() {
            CheckCapsuleMap(false);
            CheckCapsuleMap(true);
        }
        static void CheckCapsuleMap(bool localMap) {
            Reset();
            bool loading = false, departure = false, mapLoaded = false;
            messageHandler.action = m => {
                if (m.command == -65) { Controller.isStopReadMessage = true; departure = true; }
                if (m.command == -24) { loading = !localMap; mapLoaded = localMap; departure = false; }
                if (m.command == 10) { loading = false; mapLoaded = true; }
            };
            Enqueue(-65); Enqueue(-22); Enqueue(-24);
            update();
            Require(messageHandler.received.Count == 1 && departure && !loading && Count() == 2,
                "Capsule pause was bypassed: following map packets erased departure animation");
            if (!localMap) Enqueue(10); // Template response joins behind older packets.
            NextFrame();
            Require(Count() == (localMap ? 2 : 3), "Paused pump consumed map data");
            Controller.isStopReadMessage = false; // Existing Teleport completion.
            Drain();
            if (localMap) Sequence(-65, -22, -24); else Sequence(-65, -22, -24, 10);
            Require(mapLoaded && !loading, "Map did not complete after resume, localMap=" + localMap);
        }
        static void FrameBudget() {
            Reset(); for (int i = 0; i < 1000; i++) Enqueue(i);
            update(); int first = messageHandler.received.Count;
            Require(first > 0 && first <= 64 && Count() == 1000 - first, "Receive burst exceeded 64-packet frame budget");
            for (int i = 0; i < 5; i++) update();
            Require(messageHandler.received.Count == first, "Repeated OnGUI callback spent another frame budget");
            Drain();
            Require(messageHandler.received.Count == 1000, "Burst lost packets");
            for (int i = 0; i < 1000; i++) Require(messageHandler.received[i] == i, "Burst reordered packets");
        }
        static void TimeBudget() {
            Reset();
            // Warm the production dispatch/JIT before measuring a slow handler.
            Enqueue(0); update(); NextFrame();
            messageHandler.received.Clear();
            messageHandler.action = m => Thread.Sleep(10);
            Enqueue(1); Enqueue(2); update();
            Require(messageHandler.received.Count == 1 && Count() == 1, "Slow handler did not yield to the next frame");
            messageHandler.action = null; Drain(); Sequence(1, 2);
        }
        static void ArrivalsAndException() {
            Reset();
            messageHandler.action = m => {
                if (m.command == 1) {
                    var producer = new Thread(() => Enqueue(3)); producer.Start();
                    Require(producer.Join(2000), "Handler ran with the receive queue lock held");
                    throw new InvalidOperationException("test callback failure");
                }
            };
            Enqueue(1); Enqueue(2);
            try { update(); } catch (InvalidOperationException) { }
            Require(Count() == 2, "Callback failure lost the unprocessed tail");
            messageHandler.action = null; Drain(); Sequence(1, 2, 3);
        }
        static void MainThreadArrival() {
            Reset();
            Main.mainThreadName = Thread.CurrentThread.Name;
            Controller.isStopReadMessage = true; Enqueue(1);
            Require(messageHandler.received.Count == 0 && Count() == 1, "Main-thread arrival bypassed pause/FIFO");
            Controller.isStopReadMessage = false; Drain(); Sequence(1);
        }
        static void EmptyAndPausedFrame() {
            Reset(); update(); Enqueue(1); update();
            Require(messageHandler.received.Count == 1, "Empty pump consumed the frame budget");
            Reset(); Controller.isStopReadMessage = true; Enqueue(2); update();
            Controller.isStopReadMessage = false; update();
            Require(messageHandler.received.Count == 1, "Paused pump consumed the frame budget");
        }
        public static string Run() {
            var failures = new List<string>();
            var tests = new Action[] { CapsulePauseResume, FrameBudget, TimeBudget, ArrivalsAndException, MainThreadArrival, EmptyAndPausedFrame };
            foreach (var test in tests) {
                try { test(); } catch (Exception ex) { failures.Add(test.Method.Name + ": " + ex.Message); }
            }
            return failures.Count == 0 ? "PASS 6 scenarios" : "FAIL " + String.Join("; ", failures.ToArray());
        }
    }
}
'@
        $harness = $harness.Replace('NAMESPACE', $namespace).Replace('RECEIVE_FIELD', $field).Replace('RECEIVE_MEMBERS', $members)
        # Usings in MyVector must precede every namespace declaration.
        $vector = $vector.Replace('using System.Collections;', '')
        Add-Type -TypeDefinition ("using System.Collections;`n" + $harness + "`n" + $vector) -Language CSharp
        $type = "$namespace.Pump" -as [type]
        $result = $type.GetMethod('Run').Invoke($null, @())
        Write-Output "$game/$session : $result"
        if ($result.StartsWith('FAIL')) { $failures += "$game/$session : $result" }
    }
}
if ($failures.Count) { throw "$($failures.Count) receive implementations failed regression checks." }
