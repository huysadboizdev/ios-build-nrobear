# Instant transmission client fix and APK plan

**Goal:** Prevent DCTT local position divergence and export a verified APK.

**Architecture:** The local actor waits for authoritative packet123; remote-player prediction is preserved. No movement guard bypass or server changes.

**Tech stack:** Unity C#, PowerShell in-memory source tests, Android IL2CPP.

- [x] Write `Tests/InstantTransmissionChecks.ps1` from the existing diagnostic; confirm it detects the old-source failure.
- [x] In both `Assets/Scripts/Assembly-CSharp/Game{1,2}/Char.cs`, guard local prediction/effect/telePortSkill assignments with `if (!me)` and retain paint remapping.
- [x] Extend `Assets/Editor/HighSpeedSkillRegression.cs` with local DCTT assertions for seven paint IDs in the distribution Verify entrypoint.
- [x] Run InstantTransmissionChecks (86 cases per tab), ManualMobAttackChecks and CapsuleReceiveChecks; review scoped changes.
- [x] Build Android IL2CPP APK with ARMv7/ARM64 in a fresh timestamped distribution directory. The original Unity process held the project lock, so the build used a temporary source copy and left that process open.
- [x] Verify APK signature, ARMv7/ARM64 libraries, ZIP integrity, build summary, distribution regression output and SHA-256. On-device testing remains outstanding.
