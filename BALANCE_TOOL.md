# Balance Tuning Tool

The Balance Tuning Tool is a debug/editor-only workflow for turning saved telemetry into a previewable balance patch. It is available from the result screen debug section after a run produces telemetry.

## Data Source

Saved reports are read from:

```text
user://telemetry/*.json
```

The tool uses `TelemetryReportLoader` to load reports for the current `level_id`, aggregate the runs, and find the latest report. Do not rely on one run only; use several representative clears and failures before applying persistent data changes.

## Generate And Preview

1. Finish or load a level result in a debug/editor build.
2. Open `BALANCE TUNING TOOL`.
3. Press `Analyze Saved Reports`.
4. Press `Generate Balance Patch`.
5. Press `Preview Patch`.

Preview is mandatory by design. It shows a readable `[BALANCE_PATCH_PREVIEW]` with the level, report count, risk, proposed reward changes, wave spacing/composition changes, expected effect, and a warning that no production data has changed yet.

## Runtime Patch

`Apply Runtime Patch` modifies the current `WaveManager.waves` data in memory only. It does not write to `res://` and is intended for immediate debug testing. The tool refuses to apply a runtime patch while a wave is already running.

Runtime apply now prints the target path, deterministic wave-data hash, before/after diff, `WaveManager` reload confirmation, and the dominant strategy test result. A patch is not considered successful unless the real wave data changed and `2x_lightning_l3_only` fails or leaks.

## Persistent File Patch

`Apply File Patch` is only enabled in debug/editor builds. Before writing, it:

- validates the selected `level_id`
- loads the affected waves JSON
- validates enemy references, rewards, wave count, and non-empty waves
- creates a backup in `user://balance_backups/level_TIMESTAMP/`
- writes the patched JSON
- reads the file back and validates it again

Success is printed only after write and read-back validation pass.

File apply also prints `[BALANCE_PATCH_FILE_VERIFY]` with expected and actual read-back hashes. Duplicate clicks of the same patch are rejected with `[BALANCE_PATCH_ALREADY_APPLIED]` so rewards and wave pressure are not multiplied blindly.

## Rollback

`Rollback Last Patch` restores the most recent backup manifest for the selected level and prints:

```text
[BALANCE_PATCH_ROLLBACK] restored=...
```

Reload the level after rollback before retesting.

## Tests

`Run Dominant Strategy Test` checks the selected level against the required `2x_lightning_l3_only` strategy. For `level_20`, the desired verdict is `PASS`, meaning that the dominant strategy fails or leaks.

`Run Mixed Defense Test` is an optional fairness check using Lightning plus Rapid/Sniper/Slow/Cannon. For `level_20`, mixed defense should remain clearable, and perfect clear should remain possible.

If the dominant strategy still clears cleanly, the tool prints `[BALANCE_PATCH_ESCALATE]` and prepares a Stage 2 patch preview instead of claiming success.

## Production Builds

All balance tool buttons are hidden outside debug/editor builds. This prevents production players from seeing telemetry tooling, applying runtime balance changes, or writing development JSON patches.
