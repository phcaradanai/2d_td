#!/usr/bin/env python3
"""
campaign_smoke_test.py
Full Campaign Smoke Test & Auto-Clear Validation Pass
Statically validates all 20 levels without running Godot.
"""

import json, os, sys, math
from pathlib import Path

BASE = Path("/Users/oyl/my_folders/projects/clone tower defend")

ENEMIES = json.loads((BASE / "data/enemies.json").read_text())
TOWERS  = json.loads((BASE / "data/towers.json").read_text())

# ─── HP / reward / category tables ─────────────────────────────────────────
HP      = {k: v["max_hp"]      for k, v in ENEMIES.items()}
GOLD    = {k: v["reward_gold"] for k, v in ENEMIES.items()}
CAT     = {k: v["category"]    for k, v in ENEMIES.items()}   # "land" | "air"
SPEED   = {k: v["speed"]       for k, v in ENEMIES.items()}

TOWER_COST = {k: v["cost"] for k, v in TOWERS.items()}
# Which tower types target air?
AA_TOWERS  = {k for k, v in TOWERS.items() if "air" in v.get("target_categories", [])}
# -> {"rapid_tower", "sniper_tower", "lightning_tower"}

# Base DPS per tower (level-1 stats)
def tower_dps(tid):
    cfg  = TOWERS[tid]
    lvl1 = cfg["levels"][0]
    d    = lvl1["damage"]
    fr   = lvl1["fire_rate"]  # seconds between shots
    return d / fr             # damage per second

BASE_DPS = {k: tower_dps(k) for k in TOWERS}

# ─── Helpers ────────────────────────────────────────────────────────────────
def load_json(p):
    return json.loads(Path(p).read_text())

def all_path_cells(level):
    """Return a flat list of [col, row] cells from 'paths' or 'path_cells'."""
    cells = []
    if "paths" in level:
        for lane in level["paths"].values():
            cells.extend(lane)
    elif "path_cells" in level:
        cells.extend(level["path_cells"])
    return cells

def path_is_connected(points):
    """Return list of gaps (non-adjacent steps) in a path."""
    gaps = []
    for i in range(len(points) - 1):
        a, b = points[i], points[i+1]
        if abs(a[0]-b[0]) + abs(a[1]-b[1]) > 1:
            gaps.append((a, b))
    return gaps

def wave_hp_and_gold(groups):
    total_hp = 0
    total_gold = 0
    for g in groups:
        t = g.get("type", g.get("enemy_type", ""))
        c = g.get("count", 0)
        if t not in HP:
            continue
        total_hp   += HP[t] * c
        total_gold += GOLD[t] * c
    return total_hp, total_gold

def wave_has_air(groups):
    return any(CAT.get(g.get("type", g.get("enemy_type","")), "land") == "air"
               for g in groups)

def wave_has_land(groups):
    return any(CAT.get(g.get("type", g.get("enemy_type","")), "land") == "land"
               for g in groups)

def wave_enemy_types(groups):
    return [g.get("type", g.get("enemy_type","")) for g in groups]

def level_has_aa_possible(level):
    """True if at least one buildable cell exists and AA towers are in the game."""
    return bool(level.get("buildable_cells")) and bool(AA_TOWERS)

def path_length_cells(level):
    """Average number of path cells across lanes."""
    if "paths" in level:
        lanes = list(level["paths"].values())
        return sum(len(l) for l in lanes) / len(lanes)
    return len(level.get("path_cells", []))

def approx_path_seconds(level):
    """Rough exposure time in seconds: path length (cells) × grid_size / avg_speed."""
    grid = level.get("grid_size", 64)
    # Use basic enemy speed as reference (90 px/s)
    avg_speed = 90
    return path_length_cells(level) * grid / avg_speed

def estimate_max_dps_at_level(starting_gold, wave_rewards_before, enemy_kills_before):
    """Rough estimate of player DPS by a given wave based on gold budget."""
    total = starting_gold + wave_rewards_before + enemy_kills_before
    # Heuristic: optimal spend is mix of Basic (50g, 15 DPS) and Cannon (110g, 12.8 DPS splash)
    # Average effective DPS per gold ≈ 0.28 DPS/g for first few towers
    towers = max(1, int(total / 75))     # avg tower cost
    avg_dps_per_tower = 16               # ballpark mid-mix
    return towers * avg_dps_per_tower

# ─── Main validator ─────────────────────────────────────────────────────────
RESULTS = {}

def validate_level(level_num):
    lid   = f"level_{level_num:02d}"
    lpath = BASE / f"data/levels/{lid}.json"
    if not lpath.exists():
        return {"id": lid, "status": "MISSING_FILE", "issues": [f"Level JSON not found: {lpath}"]}

    level  = load_json(lpath)
    wpath  = BASE / "data/waves" / f"waves_{level_num:02d}.json"
    if not wpath.exists():
        return {"id": lid, "status": "MISSING_WAVES", "issues": [f"Waves JSON not found: {wpath}"]}

    waves = load_json(wpath)
    issues  = []
    warnings = []

    # ── 1. Schema checks ────────────────────────────────────────────────────
    required_fields = ["id", "area_id", "area_name", "difficulty",
                       "grid_size", "grid_cols", "grid_rows", "starting_gold",
                       "starting_lives", "buildable_cells", "waves_path"]
    for f in required_fields:
        if f not in level:
            issues.append(f"SCHEMA: Missing field '{f}'")

    # ── 2. Path connectivity ─────────────────────────────────────────────────
    if "paths" in level:
        for lane_id, pts in level["paths"].items():
            if len(pts) < 2:
                issues.append(f"PATH: lane '{lane_id}' has < 2 points")
            gaps = path_is_connected(pts)
            for a, b in gaps:
                issues.append(f"PATH: lane '{lane_id}' has jump {a}→{b} (non-adjacent)")
    elif "path_cells" in level:
        pts  = level["path_cells"]
        if len(pts) < 2:
            issues.append("PATH: path_cells has < 2 points")
        gaps = path_is_connected(pts)
        for a, b in gaps:
            issues.append(f"PATH: jump {a}→{b} (non-adjacent)")
    else:
        issues.append("PATH: No 'paths' or 'path_cells' defined")

    # ── 3. Buildable cell validation ─────────────────────────────────────────
    buildable = level.get("buildable_cells", [])
    blocked   = level.get("blocked_cells", [])
    path_set  = set(tuple(c) for c in all_path_cells(level))
    cols = int(level.get("grid_cols", 20))
    rows = int(level.get("grid_rows", 12))

    if not buildable:
        warnings.append("BUILD: No buildable_cells defined (free-build mode)")
    else:
        if len(buildable) < 6:
            issues.append(f"BUILD: Only {len(buildable)} buildable cells (< 6 minimum)")
        for c in buildable:
            tc = tuple(c)
            if tc in path_set:
                issues.append(f"BUILD: Cell {list(c)} overlaps enemy path ← CRITICAL")
            if c[0] < 0 or c[0] >= cols or c[1] < 0 or c[1] >= rows:
                issues.append(f"BUILD: Cell {list(c)} outside grid bounds ({cols}×{rows})")
            if tuple(c) in set(tuple(b) for b in blocked):
                issues.append(f"BUILD: Cell {list(c)} is in blocked_cells")

    # ── 4. Guardian checks (levels 11–20) ───────────────────────────────────
    hero_enabled = level.get("hero_enabled", False)
    if level_num >= 11 and not hero_enabled:
        warnings.append("GUARDIAN: Level 11+ but hero_enabled is false/missing")

    # ── 5. Wave analysis ─────────────────────────────────────────────────────
    if not isinstance(waves, list) or len(waves) == 0:
        issues.append("WAVES: Wave file is empty or not an array")
        return _result(lid, issues, warnings, {})

    cumulative_wave_rewards = 0
    cumulative_enemy_gold   = 0
    starting_gold           = int(level.get("starting_gold", 0))

    wave_summary = []
    first_air_wave = None
    has_air_any    = False
    has_bulwark    = False
    known_types    = set(ENEMIES.keys())

    for wi, wave in enumerate(waves):
        wnum   = wi + 1
        groups = wave.get("groups", [])

        if not groups:
            issues.append(f"WAVE {wnum}: Empty groups list")
            continue

        # Unknown enemy types
        for g in groups:
            t = g.get("type", g.get("enemy_type", ""))
            if t and t not in known_types:
                issues.append(f"WAVE {wnum}: Unknown enemy type '{t}'")

        whp, wgold = wave_hp_and_gold(groups)
        cumulative_enemy_gold += wgold
        if wi > 0:
            rew = waves[wi-1].get("reward", waves[wi-1].get("completion_reward", 0))
            cumulative_wave_rewards += rew

        # Air/AA check
        if wave_has_air(groups):
            has_air_any = True
            if first_air_wave is None:
                first_air_wave = wnum
            # Ensure level has potential AA coverage
            if not level_has_aa_possible(level) and not any(
                g.get("type","") in [t.replace("_tower","") for t in AA_TOWERS]
                for g in groups
            ):
                warnings.append(f"WAVE {wnum}: Air enemies present but level may have no AA build spots")

        # Bulwark first-group check — per lane (multi-lane waves have different paths)
        lanes = {}
        for g in groups:
            lane = g.get("path", "default")
            lanes.setdefault(lane, []).append(g.get("type", g.get("enemy_type","")))
        for lane_id, types in lanes.items():
            if "bulwark" in types and types[0] != "bulwark":
                issues.append(f"WAVE {wnum} lane='{lane_id}': Bulwark is NOT first group (Bulwark rule violation) — order: {types}")


        # HP capacity estimate
        budget = starting_gold + cumulative_wave_rewards + cumulative_enemy_gold
        est_dps = estimate_max_dps_at_level(starting_gold, cumulative_wave_rewards, cumulative_enemy_gold)
        path_t  = approx_path_seconds(level)
        capacity = est_dps * path_t

        btypes = [g.get("type", g.get("enemy_type","")) for g in groups]
        trivial    = whp < capacity * 0.25
        impossible = whp > capacity * 3.0 and wnum > 1

        ws = {
            "wave": wnum,
            "name": wave.get("name", "?"),
            "hp": whp,
            "enemy_gold": wgold,
            "reward": wave.get("reward", wave.get("completion_reward", 0)),
            "capacity_est": round(capacity),
            "hp_ratio": round(whp / max(1, capacity), 2),
            "has_air": wave_has_air(groups),
            "has_land": wave_has_land(groups),
            "enemy_types": list(set(btypes)),
            "trivial": trivial,
            "impossible": impossible,
        }
        wave_summary.append(ws)

        if impossible:
            issues.append(f"WAVE {wnum} '{ws['name']}': HP={whp} vs capacity≈{int(capacity)} → ratio {ws['hp_ratio']} (likely impossible)")
        elif trivial and wnum == len(waves):
            warnings.append(f"WAVE {wnum} '{ws['name']}': Final wave HP ratio={ws['hp_ratio']} (may be too trivial)")

        # Air-only wave with no land check (Guardian wasted)
        if wave_has_air(groups) and not wave_has_land(groups) and hero_enabled:
            warnings.append(f"WAVE {wnum}: Air-only wave — Guardian does nothing (correct design, note only)")

        # Intel present for new mechanics?
        has_intel = bool(wave.get("intel", ""))
        new_mechs = {g.get("type","") for g in groups} & {
            "swarm","runner","shieldbearer","healer","splitter",
            "bulwark","cloaked","flyer","fast_flyer","armored_flyer","disruptor","hunter"
        }
        first_new = first_wave_of_type(level_num, new_mechs)
        if first_new and not has_intel:
            warnings.append(f"WAVE {wnum}: First appearance of {first_new} but no 'intel' field")

    # Air + no AA warning
    if has_air_any and level_num >= 16:
        roles = [r.lower() for r in level.get("recommended_roles", [])]
        aa_roles = {"sniper","rapid","lightning","aa","anti-air","anti_air"}
        if not aa_roles.intersection(set(roles)):
            warnings.append("AIR: Level has air enemies but no AA tower in recommended_roles")

    # ── 6. Gold flow sanity ──────────────────────────────────────────────────
    total_rewards = sum(w.get("reward", w.get("completion_reward", 0)) for w in waves)
    total_enemy_gold = sum(wave_hp_and_gold(w.get("groups",[]))[1] for w in waves)
    if starting_gold < 100:
        issues.append(f"GOLD: starting_gold={starting_gold} is very low (< 100g)")
    if total_rewards < 100:
        warnings.append(f"GOLD: Total wave rewards only {total_rewards}g across all waves")

    return _result(lid, issues, warnings, {
        "area": f"{level.get('area_id','?')} - {level.get('area_name','?')}",
        "difficulty": level.get("difficulty","?"),
        "starting_gold": starting_gold,
        "total_wave_rewards": total_rewards,
        "total_enemy_gold_est": total_enemy_gold,
        "buildable_count": len(buildable),
        "path_count": len(level.get("paths", {})) if "paths" in level else (1 if level.get("path_cells") else 0),
        "wave_count": len(waves),
        "hero_enabled": hero_enabled,
        "has_air": has_air_any,
        "first_air_wave": first_air_wave,
        "waves": wave_summary,
    })

FIRST_WAVE_CACHE = {}
def first_wave_of_type(level_num, types):
    """Check if any type in 'types' appears for the first time in THIS level."""
    # Simplified: check only if it's a known introduction level
    INTRO_MAP = {
        4: {"swarm","runner"},
        6: {"shieldbearer"},
        7: {"healer"},
        8: {"splitter"},
        11: {"bulwark","hunter"},
        13: {"cloaked"},
        16: {"flyer"},
        17: {"fast_flyer"},
        18: {"armored_flyer"},
        19: {"disruptor"},
    }
    intro = INTRO_MAP.get(level_num, set())
    return intro.intersection(types) or None

def _result(lid, issues, warnings, meta):
    critical = [i for i in issues if "CRITICAL" in i or "overlap" in i.lower() or "impossible" in i.lower()]
    return {
        "id": lid,
        "status": "FAIL" if issues else ("WARN" if warnings else "PASS"),
        "critical": critical,
        "issues": issues,
        "warnings": warnings,
        "meta": meta,
    }

# ─── Run ─────────────────────────────────────────────────────────────────────
print("=" * 70)
print("CAMPAIGN SMOKE TEST — All 20 Levels")
print("=" * 70)

all_results = []
for i in range(1, 21):
    r = validate_level(i)
    all_results.append(r)

# ─── Summary output ──────────────────────────────────────────────────────────
passes   = [r for r in all_results if r["status"] == "PASS"]
warns    = [r for r in all_results if r["status"] == "WARN"]
fails    = [r for r in all_results if r["status"] == "FAIL"]
missing  = [r for r in all_results if "MISSING" in r["status"]]

print(f"\n{'─'*70}")
print(f" RESULTS: {len(passes)} PASS  |  {len(warns)} WARN  |  {len(fails)} FAIL  |  {len(missing)} MISSING")
print(f"{'─'*70}\n")

for r in all_results:
    m    = r.get("meta", {})
    icon = "✅" if r["status"]=="PASS" else ("⚠️ " if r["status"]=="WARN" else "❌")
    diff = m.get("difficulty","?")
    gold = m.get("starting_gold","?")
    hero = "🗡 " if m.get("hero_enabled") else "  "
    air  = "✈ " if m.get("has_air") else "  "
    bld  = m.get("buildable_count","?")
    wc   = m.get("wave_count","?")
    print(f"{icon} {r['id']}  [{diff:8s}]  gold={gold}  builds={bld}  waves={wc}  {hero}{air}")

    for issue in r.get("issues", []):
        print(f"    ❌ {issue}")
    for warn in r.get("warnings", []):
        print(f"    ⚠  {warn}")

    # Wave breakdown
    for ws in m.get("waves", []):
        ratio = ws["hp_ratio"]
        flag  = ""
        if ws["impossible"]: flag = " ← ❌ IMPOSSIBLE"
        elif ws["trivial"]:  flag = " ← ⚠ TRIVIAL"
        elif ratio > 1.8:    flag = " ← ⚠ HIGH"
        air_tag = " [AIR]" if ws["has_air"] else ""
        if flag or air_tag:
            print(f"       W{ws['wave']} '{ws['name']}': hp={ws['hp']} cap≈{ws['capacity_est']} ratio={ratio}{air_tag}{flag}")

print(f"\n{'─'*70}")
print("CRITICAL ISSUES SUMMARY:")
any_crit = False
for r in all_results:
    for c in r.get("critical", []):
        print(f"  {r['id']}: {c}")
        any_crit = True
if not any_crit:
    print("  None found ✅")

print(f"\n{'─'*70}")
print("HP RATIO DANGER ZONES (ratio > 2.5):")
any_danger = False
for r in all_results:
    for ws in r.get("meta",{}).get("waves",[]):
        if ws["hp_ratio"] > 2.5:
            print(f"  {r['id']} W{ws['wave']}: hp={ws['hp']} cap≈{ws['capacity_est']} ratio={ws['hp_ratio']}")
            any_danger = True
if not any_danger:
    print("  None ✅")

print(f"\n{'─'*70}")
# Save JSON report
out = BASE / "data" / "smoke_test_report.json"
out.write_text(json.dumps(all_results, indent=2))
print(f"Full JSON report saved to: {out}")
print("Done.")
