# STEP_40S_INITIAL_SETUP_COST_AS_STARTING_GOLD.md

## 1. Goal
The goal is to redefine "Recommended Starting Gold" as the actual cost of the initial tower setup placed before Wave 1 begins in a successful Auto Clear run. This prevents saving excessive debug gold and ensures level balancing is based on the minimum necessary resources.

## 2. Definitions
- **Debug Tested Gold**: The amount of gold manually or automatically provided to the verifier for testing (e.g., 260).
- **Initial Setup Cost**: The sum of costs of all towers placed during the `APPLYING_INITIAL_ACTIONS` phase (before Wave 1 starts).
- **Verified Starting Gold**: The Initial Setup Cost of a successful perfect run.

## 3. Data Tracking
- `auto_clear_initial_setup_actions`: List of tower placements before Wave 1.
- `auto_clear_initial_setup_cost`: Cumulative cost of those placements.

## 4. Exclusion Rules
The following are **NOT** included in the Recommended Starting Gold:
- Leftover gold from the initial allotment.
- Gold earned from enemy kills or wave rewards.
- Towers placed during waves (In-Wave actions).
- Upgrades purchased at any time (for now).
- Towers placed between Wave 1 and Wave 2 (After-Wave/Before-Wave actions).

## 5. Recommended starting_gold Calculation
`recommended_starting_gold = initial_setup_cost`

## 6. Success Reporting
When a run completes successfully:
- Report `Debug starting_gold tested`.
- Report `Initial setup cost before Wave 1`.
- Set `Recommended starting_gold = Initial setup cost`.

## 7. Application Rules
When applying verified gold to a level configuration:
- Use the `Initial setup cost`.
- Update the level's `starting_gold` in the source JSON or configuration manager.
