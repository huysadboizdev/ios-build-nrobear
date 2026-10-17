# Earth instant transmission position correction

User authorized a client fix and APK export on 2026-10-17. The diagnosed failure is local teleport prediction followed by a movement prerequisite that refuses to run while telePortSkill is set; the server never receives the cast needed to release the flag.

For the local actor, map paints 128–134 to the existing attack animation without predicting coordinates or setting telePortSkill. Existing attack dispatch first synchronizes real walking movement, then sends the skill. The server already moves the actor and returns packet 123/type 1. Preserve that response path and its effects, synchronization and flag cleanup. Preserve existing prediction for remote actors.

This avoids introducing prediction rollback, request timers or special movement exemptions. A rejected or failed local cast never changes local position or sets a persistent teleport flag. Regular movement/attack safety checks remain unchanged. The tradeoff is that local teleport visuals now wait for the server's existing position response.

Verify both tabs at all seven paint IDs, mob and player targets, equal/different X/Y positions, delayed/absent replies and subsequent movement. Run existing real attack callback/retry tests plus capsule queue regression. Add a Unity Editor integration assertion for actual local setSkillPaint behavior, then build an Android 6+ ARMv7/ARM64 APK. Verify build status, ZIP integrity, signature and source hashes; keep old APKs. Do not touch server source/JAR or commit unrelated work.
