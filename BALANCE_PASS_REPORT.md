# Balance Pass Report: Level 20 Dominant Strategy

## Problem: Lightning Tower Exploit
Telemetry and manual testing confirmed that Level 20 could be cleared using only 2 Lightning Towers upgraded to Level 3. This undermined the "Final Exam" design of the level, which was intended to require a mixed tower strategy and hero tactical support.

### Root Cause Analysis
1. **Wave Density**: Enemies were spawned in tight clusters, maximizing the efficiency of the Lightning Tower's chain mechanic.
2. **Infinite Coverage**: High `chain_range` allowed a single tower to cover massive portions of the path, including both lanes in some areas.
3. **Economic Spike**: Early wave rewards allowed players to reach Level 3 upgrades too quickly, trivializing mid-game pressure.
4. **Lack of Punishers**: Insufficient fast or armored units allowed slow-chaining towers to manage all threats.

## Changes Made

### 1. Level 20 Wave Rebalance (`data/waves/waves_20.json`)
- **Spacing**: Increased intervals between enemies in swarms and tank groups.
- **Split Pressure**: Aggressive Lane A/Lane B synchronization forces players to defend multiple points simultaneously.
- **Unit Mix**:
    - Increased `fast_flyer` and `runner` counts to punish slow chaining.
    - Added more `armored_flyer` and `bulwark` units to necessitate single-target DPS (Sniper/Rapid).
    - Introduced specialized pressure waves where Hero intervention is highly recommended.
- **Economy**: Reduced early wave rewards (Waves 1-3) to delay high-tier upgrades.

### 2. Lightning Tower Tuning (`data/towers.json`)
- **Chain Range**: Reduced by ~15% across all levels (L1: 90, L2: 105, L3: 120). This reduces universal coverage and requires tighter grouping for max value.
- **Cost Gating**: Increased upgrade costs (L1->L2: 130, L2->L3: 240) to force more strategic resource allocation.

### 3. Telemetry Enhancements (`scripts/core/battle_telemetry.gd`)
- **Dominant Strategy Detection**: Added logic to flag "Few-tower Lightning clears".
- **Variety Tracking**: Now reports `tower_variety_count` and `tower_total_count` to identify exploits.

## Test Results

| Scenario | Result (Before) | Result (After) | Verdict |
| :--- | :--- | :--- | :--- |
| **2x Lightning L3 Only** | Perfect Clear | **FAIL** (Leaked in Wave 2/3) | **PASS** |
| **Mixed Defense** | Clear | **Clear** (Required more gold management) | **PASS** |
| **No Hero Clear** | Easy | **Challenging** | **PASS** |

## Remaining Risks
- Sniper dominance might become the next strategy for armored flyers.
- Players may still find "optimal" placements that maximize the reduced chain range.
- Economy might be too tight for casual players on Level 20; monitor `gold_remaining_ratio` in future reports.
