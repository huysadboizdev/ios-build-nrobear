# APK v3 — Cadíc animation fix, 15/10/2026

Install `Android/NRO.apk` as an update over v2. Package and signing certificate match v2. Fully close and reopen the game after installation.

Android 6/API23 minimum; IL2CPP ARMv7 + ARM64; landscape. Server remains `160.191.245.239:14445`.

The build includes the Game1/Game2 Mob.GetFrame checks: missing or invalid custom animation tables retain the existing default sequences and can recover when valid data arrives. This protects the update loop even if the server still sends the malformed mob95 x4 metadata. Server resource changes have not been deployed to the VPS.

Check Sa Mạc Hoang Vu/map165 on the affected Android6 device: farm and move for several minutes, verify mobs animate, damage/miss text expires, combat projectiles/effects advance and disappear; repeat in tab2 if used. Record any remaining freeze and its timing. Physical-device gameplay is not yet verified.

Unity build succeeded: 0 errors, 82 warnings. Existing prebuild Unity checks passed; MobFrameRecoveryChecks.py also passed before build. APK signature, same certificate/package as v2, ZIP integrity/alignment, both ABIs and ARM64 ELF alignment verified. Details: `Android/verification.json`, `Android/signature.txt`, `unity-build-retry.log`.

APK: 84,179,293 bytes.

SHA-256: `fbaf22b76f3f4ab24b855cef54a1552691d38170b414f30144fe6ee51bb79073`.
