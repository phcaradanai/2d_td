# Changelog

## [1.1.0] - 2026-05-08
### Added
- **Battle Telemetry System**: Robust data-driven engine for tracking all gameplay metrics.
- **Balance Report UI**: Debug-only summary on the Result Screen showing MVP tower, top leaks, and economy efficiency.
- **JSON Export**: Automatic serialization of battle reports to `user://telemetry/` for post-game analysis.

### Changed
- Refactored `GameManager` and `WaveManager` to support decoupled telemetry hooks.
- Upgraded `Tower` and `Hero` systems to report granular damage types.
- Enhanced `ResultPanel` with interactive record feedback (Efficiency, MVP, Leak stats).
