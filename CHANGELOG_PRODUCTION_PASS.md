# Production Readiness Pass Changelog

This document summarizes the changes made during the Production Readiness Phase to prepare the game for full release.

## Balance & Progression
* **Level 20 Difficulty Spike Addressed:** Increased starting gold to 500 to allow a stronger initial defense. Softened the Wave 1 and Wave 2 opening density by increasing spawn intervals for `bulwark` and `fast_flyer` enemies.

## Analytics & Tuning
* **Telemetry Manager Introduced:** Added `TelemetryManager` as an autoload to track session statistics (Gold Efficiency, Time, Kill/Leak counts, Towers Built).
* **Result Screen Update:** The post-game Result Panel now displays a clear "GOLD EFFICIENCY" metric based on the telemetry data.

## Player Experience & UI Polish
* **Target Priority System:** Existing target sorting modes (`First`, `Last`, `Nearest`, `Strongest`, `Weakest`) are now fully linked to the HUD's Tower Info panel, allowing the player to easily toggle priority mid-battle.
* **Wave Intel Clarity:** The UI Wave Intel Panel now correctly parses and updates preview summaries and enemy threats dynamically.
* **Role Hints added to Build Preview:** While hovering to place a tower, players will now see a concise description (e.g. "Area Damage / Splash") floating next to the placement validity reason.
* **Target Marker Polish:** The pulsing target marker for selected towers has been intensified (speed 4.0 -> 6.0, magnitude 0.2 -> 0.35) for improved readability.

## Quality Assurance
* **QA Suite Validation:** Created `scripts/debug/qa_suite.gd`. Successfully validated that all 20 levels and their waves have valid JSON syntax, no overlapping path/build-zones, and intact required properties.
