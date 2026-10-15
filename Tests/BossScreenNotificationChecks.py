"""Boss screen notification filter checks (Task 3).

New wire contract (Task 2): additive command 115 v2 carries
  schema, version, eventKey, semanticId, form, mapId, mapType, ticker,
  hiddenFromPanel.
Command 93 stays ticker-only.

Runs without Unity: compiles the pure BossScreenNoticeData helper in
isolation with csc.exe, runs the visibility matrix, then source-checks
both tab integrations (dispatcher / overlay / hit-test).
Run: python Tests/BossScreenNotificationChecks.py
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CSC = Path("C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe")
HELPER = ROOT / "Assets/Scripts/Assembly-CSharp/BossScreenNoticeData.cs"


def block(source, marker):
    start = source.index(marker)
    begin = source.index("{", start)
    depth = 1
    end = begin + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


FILTER_MATRIX_SHELL = r'''
using System;
namespace Game1 {
    public class myReader {
        private readonly byte[] bytes; private int position;
        public myReader(byte[] value) { bytes = value; }
        public int readUnsignedByte() { return bytes[position++]; }
        public int readInt() { return (readUnsignedByte() << 24) | (readUnsignedByte() << 16) | (readUnsignedByte() << 8) | readUnsignedByte(); }
        public string readUTF() { int length = (readUnsignedByte() << 8) | readUnsignedByte(); string result = ""; for (int i = 0; i < length; i++) result += (char)readUnsignedByte(); return result; }
        public bool readBoolean() { return readUnsignedByte() != 0; }
    }
}
namespace Game2 {
    public class myReader {
        private readonly byte[] bytes; private int position;
        public myReader(byte[] value) { bytes = value; }
        public int readUnsignedByte() { return bytes[position++]; }
        public int readInt() { return (readUnsignedByte() << 24) | (readUnsignedByte() << 16) | (readUnsignedByte() << 8) | readUnsignedByte(); }
        public string readUTF() { int length = (readUnsignedByte() << 8) | readUnsignedByte(); string result = ""; for (int i = 0; i < length; i++) result += (char)readUnsignedByte(); return result; }
        public bool readBoolean() { return readUnsignedByte() != 0; }
    }
}
class FilterMatrix {
    static void Check(bool condition, string message) {
        if (!condition) throw new Exception("FAIL: " + message);
    }
    static void AddInt(System.Collections.Generic.List<byte> bytes, int value) {
        bytes.Add((byte)(value >> 24)); bytes.Add((byte)(value >> 16)); bytes.Add((byte)(value >> 8)); bytes.Add((byte)value);
    }
    static void AddUtf(System.Collections.Generic.List<byte> bytes, string value) {
        bytes.Add((byte)(value.Length >> 8)); bytes.Add((byte)value.Length);
        foreach (char character in value) bytes.Add((byte)character);
    }
    static byte[] Packet(int version, bool hidden) {
        var bytes = new System.Collections.Generic.List<byte>();
        bytes.Add(1); bytes.Add((byte)version); AddUtf(bytes, "odo"); AddInt(bytes, -9998); AddInt(bytes, 7); AddInt(bytes, 8); AddInt(bytes, 9); AddUtf(bytes, "BOSS Odo"); bytes.Add((byte)(hidden ? 1 : 0));
        return bytes.ToArray();
    }
    static void Main() {
        var shown = new Game1.BossScreenNoticeData("ordinary", 100, 0, 5, 0, "BOSS ordinary", false);
        Check(Game1.BossScreenNoticeData.ShouldShow(shown), "server-visible event remains visible");
        // Dynamic identities use the server's typed flag instead of a client ID table.
        Check(!Game1.BossScreenNoticeData.ShouldShow(new Game1.BossScreenNoticeData("an-trom", -9999, 0, 5, 0, "BOSS An Trom", true)), "an trom hidden by server flag");
        Check(!Game1.BossScreenNoticeData.ShouldShow(new Game1.BossScreenNoticeData("odo", -9998, 0, 5, 0, "BOSS O do", true)), "odo hidden by server flag");
        Check(!Game1.BossScreenNoticeData.ShouldShow(new Game1.BossScreenNoticeData("mat-troi", -9997, 0, 5, 0, "BOSS Mat Troi", true)), "mat troi hidden by server flag");
        Check(Game1.BossScreenNoticeData.ShouldShow(new Game1.BossScreenNoticeData("unknown", 999999, 0, 999, 99, "BOSS unknown", false)), "unknown visible when server says visible");
        Check(Game1.BossScreenNoticeData.ShouldShow((Game1.BossScreenNoticeData)null), "null fails open");
        Game1.BossScreenNoticeData decoded;
        Check(Game1.BossScreenNoticeData.TryRead(new Game1.myReader(Packet(2, true)), out decoded), "v2 command 115 decoded");
        Check(decoded.eventKey == "odo" && decoded.semanticBossId == -9998 && decoded.form == 7 && decoded.mapId == 8 && decoded.mapType == 9 && decoded.ticker == "BOSS Odo" && decoded.hiddenFromPanel, "command 115 field order");
        Check(!Game1.BossScreenNoticeData.ShouldShow(decoded), "decoded hidden flag controls overlay");
        Check(!Game1.BossScreenNoticeData.ShouldShowLegacyFallback(false, true, 100, 200), "legacy row waits for classification");
        Check(Game1.BossScreenNoticeData.ShouldShowLegacyFallback(false, true, 200, 200), "legacy row fails open after grace period");
        Check(!Game1.BossScreenNoticeData.ShouldShowLegacyFallback(true, false, 200, 200), "hidden typed row stays hidden");
        Check(!Game1.BossScreenNoticeData.TryRead(new Game1.myReader(Packet(1, false)), out decoded), "old command 115 version rejected");
        Game2.BossScreenNoticeData decodedGame2;
        Check(Game2.BossScreenNoticeData.TryRead(new Game2.myReader(Packet(2, false)), out decodedGame2), "game2 v2 command 115 decoded");
        Check(decodedGame2.eventKey == "odo" && !decodedGame2.hiddenFromPanel && Game2.BossScreenNoticeData.ShouldShow(decodedGame2), "game2 parsed fields remain visible");
        Console.WriteLine("PASS filter matrix: server flag hides dynamic IDs, visible and legacy entries fail open");
    }
}
'''


class BossScreenNotificationChecks(unittest.TestCase):
    def test_pure_helper_filter_matrix(self):
        self.assertTrue(HELPER.is_file(), "BossScreenNoticeData.cs missing")
        helper_source = HELPER.read_text(encoding="utf-8-sig")
        self.assertIn("ShouldShow", helper_source)
        self.assertIn("ScreenVersion = 2", helper_source)
        self.assertIn("hiddenFromPanel", helper_source)
        with tempfile.TemporaryDirectory(prefix="boss-screen-filter-") as directory:
            directory = Path(directory)
            shell = directory / "FilterMatrix.cs"
            executable = directory / "FilterMatrix.exe"
            shell.write_text(FILTER_MATRIX_SHELL, encoding="utf-8-sig")
            compiled = subprocess.run(
                [str(CSC), "/nologo", "/out:" + str(executable), str(HELPER), str(shell)],
                capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, "helper must compile standalone:\n" + compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, "filter matrix failed:\n" + result.stdout + result.stderr)
            self.assertIn("PASS filter matrix", result.stdout)

    def test_both_tabs_wire_and_overlay_integration(self):
        for game in ("Game1", "Game2"):
            with self.subTest(game=game):
                folder = ROOT / "Assets/Scripts/Assembly-CSharp" / game
                controller = (folder / "Assets/src/f/Controller2.cs").read_text(encoding="utf-8-sig")

                # New additive packet.
                self.assertIn("case 115:", controller, game + ": missing command 115 handler")
                packet = block(controller, "case 115:")
                for token in ("BossScreenNoticeData.TryRead", "showBossScreenNotice"):
                    self.assertIn(token, packet, game + ": case 115 missing " + token)
                # The shared parser owns the exact wire order for both tabs.
                helper_source = HELPER.read_text(encoding="utf-8-sig")
                parser = block(helper_source, "public static bool TryRead(")
                # Wire field order: schema, version, key, id, form, map, type, ticker, hidden.
                order = ["readUnsignedByte", "readUnsignedByte", "readUTF", "readInt",
                         "readInt", "readInt", "readInt", "readUTF", "readBoolean"]
                cursor = 0
                for token in order:
                    found = parser.index(token, cursor)
                    cursor = found + len(token)

                # Command 93 stays ticker-only (no trailer magic, no hidden flag).
                command_93 = block(controller, "case 93:")
                self.assertIn("GameScr.gI().chatVip(str);", command_93, game + ": 93 must stay ticker-only")
                self.assertNotIn("hiddenFromScreenPanel", command_93, game + ": 93 must not carry hidden flag")
                self.assertNotIn("ReadBossScreenPanelHidden", controller, game + ": trailer helper removed")
                self.assertNotIn("0x424E4631", controller, game + ": trailer magic removed")

                # Typed identity in overlay, shared predicate for visibility.
                show_boss = (folder / "Mod/ShowBoss.cs").read_text(encoding="utf-8-sig")
                self.assertIn("BossScreenNoticeData", show_boss, game + ": ShowBoss must store typed identity")
                self.assertIn("public bool ShouldShowOnScreen()", show_boss)
                self.assertIn("rawTicker", show_boss, game + ": ShowBoss must keep raw ticker for dedup")
                self.assertIn("HasScreenNotice", show_boss, game + ": ShowBoss must expose typed state")
                visibility = block(show_boss, "public bool ShouldShowOnScreen()")
                self.assertIn("BossScreenNoticeData.ShouldShow", visibility,
                              game + ": visibility must use shared predicate")
                self.assertIn("ShouldShowLegacyFallback", visibility,
                              game + ": legacy fallback must wait for command 115")
                self.assertIn("ApplyScreenNotice", show_boss,
                              game + ": typed event must upgrade matching pending ticker")
                game_scr = (folder / "GameScr.cs").read_text(encoding="utf-8-sig")
                typed_handler = block(game_scr, "public void showBossScreenNotice(")
                self.assertIn("rawTicker", typed_handler, game + ": typed handler must correlate either arrival order")
                self.assertIn("ApplyScreenNotice", typed_handler,
                              game + ": typed handler must update matching row instead of duplicating")
                self.assertIn("entry.IsRecentTicker", typed_handler,
                              game + ": correlation must be limited to the same recent event")

                # Ticker preserved, overlay fed by typed event + legacy 93 fallback.
                self.assertIn("vChatVip.addElement(chatVip);", game_scr, game + ": ticker preserved")
                self.assertIn("showBossScreenNotice", game_scr, game + ": typed overlay entry point missing")
                # Legacy fallback: old server (no 115) must still feed the panel from 93.
                self.assertIn('chatVip.Trim().ToLower().Contains("boss")', game_scr,
                              game + ": 93 fallback for boss tickers missing")
                self.assertIn("new ShowBoss(chatVip)", game_scr,
                              game + ": legacy overlay entry missing")
                self.assertIn("hasBossNotifTicker", game_scr,
                              game + ": fallback dedup guard missing")
                self.assertIn("pending.AwaitScreenMetadata()", game_scr,
                              game + ": legacy panel row must wait for metadata")
                self.assertIn("removeLegacyBossNotifTicker", game_scr,
                              game + ": 115 must replace legacy entry with same ticker")

                # Drawing and hit-test skip hidden entries via the same predicate.
                mod_func = (folder / "ModFunc.cs").read_text(encoding="utf-8-sig")
                paint = block(mod_func, "public void Paint(mGraphics g)")
                self.assertIn("showBoss.ShouldShowOnScreen()", paint, game + ": draw must guard")
                touch = block(game_scr, "private void UpdateKeyTouchControl()")
                self.assertIn("showBoss.ShouldShowOnScreen()", touch, game + ": hit-test must guard")


if __name__ == "__main__":
    unittest.main(verbosity=2)
