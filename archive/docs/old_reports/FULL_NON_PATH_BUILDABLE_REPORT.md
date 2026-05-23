# Full Non-Path Buildable Report

Generated with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s scratch/test_full_non_path_buildable.gd
```

Latest result: `PASS`.

## Summary

- Default buildable mode is `full_non_path`.
- Missing `buildable_mode` now resolves to `full_non_path`.
- Existing legacy `buildable_cells` lists are ignored unless a level explicitly sets `buildable_mode` to `manual`.
- Runtime `LevelManager.buildable_cells` is generated from the full grid minus forbidden cells.
- `BuildManager.can_build_at_cell()` and placement validation use the same LevelManager/static forbidden-cell source.
- Placement preview receives the same runtime buildable/blocked sets as actual placement.
- Solver legal cells now come from `BuildableGridGenerator.generate_buildable_grid()`.
- Debug tools now include full non-path analysis, preview, runtime patch, file mode patch, disruptor counterplay validation, and all-level placement validation.

## Validation

`level_01` through `level_20` passed:

- level loads
- buildable mode resolves to `full_non_path`
- runtime buildable count matches generator
- path cells are unbuildable
- spawn cells are unbuildable
- base cells are unbuildable
- blocked cells are unbuildable
- preview/runtime `can_build` mismatch count is `0`
- disruptor safe sniper counterplay cells exist

Observed generated buildable counts ranged from `182` to `220` cells per level, replacing the old near-path-only placement restriction.
