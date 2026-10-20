import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Scripts/Assembly-CSharp"


def block(source, marker):
    start = source.index(marker)
    begin = source.index("{", start)
    depth = 1
    end = begin + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


panels = {}
services = {}
for game in ("Game1", "Game2"):
    panel = (SOURCE / game / "Panel.cs").read_text(encoding="utf-8-sig")
    controller = (SOURCE / game / "Controller.cs").read_text(encoding="utf-8-sig")
    service = (SOURCE / game / "Service.cs").read_text(encoding="utf-8-sig")
    panels[game] = panel
    services[game] = service
    assert "UpgradeBatchState upgradeBatch" in panel, game + ": shared batch state missing"
    assert "private bool HasUpgradeProtectionRequirement()" in panel
    assert "private int CountUpgradeProtectionStones()" in panel
    assert "private void StartUpgradeBatch()" in panel
    assert "private void SendNextUpgradeBatchAttempt()" in panel
    assert "public void HandleUpgradeBatchResponse(bool successful)" in panel
    assert "private void ContinueUpgradeBatchAfterEffect()" in panel
    assert "private void CancelUpgradeBatch()" in panel
    assert "Nâng cấp x100" in panel
    assert "currentListLength = vItemCombine.size() + (IsUpgradeCombineRecipe() ? 2 : 1);" in panel
    assert "selected == vItemCombine.size() + 1" in block(panel, "private void doFireCombine()")
    assert "HasUpgradeProtectionRequirement()" in block(panel, "private void StartUpgradeBatch()")
    assert "CountUpgradeProtectionStones()" in block(panel, "private void StartUpgradeBatch()")
    assert "CountUpgradeProtectionStones() >= UPGRADE_BATCH_ATTEMPTS" in block(panel, "private bool CanStartUpgradeBatch()")
    assert "CountUpgradeProtectionStones() < upgradeBatch.RemainingAttempts" in block(panel, "private void SendNextUpgradeBatchAttempt()")
    assert "upgradeBatchResponseDrainPending" in block(panel, "private void StartUpgradeBatch()")
    assert "upgradeBatch.OnEffectFinished()" in block(panel, "private void ContinueUpgradeBatchAfterEffect()")
    effect = block(panel, "private void updateCombineEff()")
    assert effect.index("isDoneCombine = true;") < effect.index("ContinueUpgradeBatchAfterEffect();")

    packet = block(controller, "case -81:")
    assert "HandleUpgradeBatchResponse(true)" in packet, game + ": b32=2 success mapping missing"
    assert "HandleUpgradeBatchResponse(false)" in packet, game + ": b32=3 failure mapping missing"
    sender = block(service, "public bool combine(sbyte action, MyVector id)")
    assert "sent = true;" in sender and "return sent;" in sender

for marker in (
    "private bool IsUpgradeCombineRecipe()",
    "private bool HasUpgradeProtectionRequirement()",
    "private int CountUpgradeProtectionStones()",
    "private void StartUpgradeBatch()",
    "private void SendNextUpgradeBatchAttempt()",
    "public void HandleUpgradeBatchResponse(bool successful)",
    "private void ContinueUpgradeBatchAfterEffect()",
    "private void CancelUpgradeBatch()",
):
    assert block(panels["Game1"], marker) == block(panels["Game2"], marker), marker + ": Game1/Game2 behavior differs"
assert block(services["Game1"], "public bool combine(sbyte action, MyVector id)") == block(
    services["Game2"], "public bool combine(sbyte action, MyVector id)"
), "combine sender differs between Game1 and Game2"

print("PASS Game1 and Game2: x100 UI, protection gate, server outcome mapping, sequential dispatch, cancellation parity")
