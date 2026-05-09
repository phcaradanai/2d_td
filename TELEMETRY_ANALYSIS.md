# Telemetry Analysis Guide

The Battle Telemetry system includes tools for aggregate analysis of saved game reports. This allows designers to track difficulty trends and balance issues across multiple playtest sessions.

## Finding Saved Reports

Telemetry data is stored in the user data directory:
- **Windows**: `%APPDATA%\Godot\app_userdata\clone tower defend\telemetry\`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/clone tower defend/telemetry/`
- **Linux**: `~/.local/share/godot/app_userdata/clone tower defend/telemetry/`

In a debug build, the absolute path is printed to the console on startup as `[TELEMETRY_PATH]`.

## Automated Analysis Tools

The system provides several ways to analyze these reports:

### 1. In-Game Debug Buttons
On the **Result Screen** (Victory/Defeat), three debug-only buttons are available:
- **View Balance Report**: Shows detailed stats for the current session.
- **Analyze All Runs**: Scans all saved reports for the current level and prints an aggregate summary to the console.
- **Export CSV Summary**: Generates a `.csv` file in the telemetry directory containing a spreadsheet-compatible summary of all runs for the current level.

### 2. Console Summary (Aggregate)
The `Analyze All Runs` tool provides the following insights:
- **Victory/Perfect Rates**: High rates (e.g., 100% victory) on difficult levels may indicate they are too easy.
- **Avg Gold Remaining Ratio**: If players consistently finish with >40% of available gold, the economy is likely too generous.
- **Tower Dominance Frequency**: Identifies if a specific tower (e.g., Lightning) is the MVP in nearly every run.
- **Hero Usage Rate**: Tracks how often the hero is deployed.

### 3. CSV Export
The exported CSV (`summary_<level_id>.csv`) can be opened in Excel, Google Sheets, or any data analysis tool. It includes columns for:
- Level ID, Result, Perfect Clear, Time, Waves.
- Gold breakdown and ratios.
- MVP Tower, Enemies Leaked, Hero Deploys.
- Automated Difficulty Rating.

## Balance Thresholds

The analyzer uses these standard thresholds to flag levels:

| Metric | Good Range | Warning (Too Easy) | Warning (Too Hard) |
| :--- | :--- | :--- | :--- |
| **Gold Remaining** | 10% - 25% | > 40% | < 5% |
| **Victory Rate** | 60% - 80% | > 95% | < 30% |
| **Tower Dominance** | < 45% | > 55% | N/A |
| **Hero Usage** | > 30% | N/A | 0% (if intended) |

## Interpreting Results

- **High Gold + High Victory Rate**: Reduce wave rewards or increase enemy HP.
- **Low Victory Rate + High Tower Dominance**: The level might be too hard unless the player uses a specific "optimal" strategy. Consider diversifying enemy resistances.
- **Low Hero Usage**: Increase the number of mobile threats or high-HP targets that require hero intervention.
