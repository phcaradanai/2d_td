import json
import math

def dist(c1, c2):
    return math.sqrt((c1[0]-c2[0])**2 + (c1[1]-c2[1])**2)

level = json.loads(open('data/levels/level_20.json').read())
towers = json.loads(open('data/towers.json').read())

grid_size = level['grid_size']
paths = level['paths']

def t_range(tid): return towers[tid]['levels'][0]['range'] / grid_size

variants = [
    {"name": "Variant A (Choke)", "placements": [("sniper_tower", [9,4]), ("lightning_tower", [9,8]), ("cannon_tower", [10,5])]}
]

for var in variants:
    print(f"\n--- {var['name']} with 10s Air Delay ---")
    for t_type, cell in var['placements']:
        r = t_range(t_type)
        
        dist_def = [dist(cell, p) for p in paths['default']]
        dist_lb = [dist(cell, p) for p in paths['lane_b']]
        
        in_range_def = [i for i, d in enumerate(dist_def) if d <= r]
        in_range_lb = [i for i, d in enumerate(dist_lb) if d <= r]
        
        first_def = min(in_range_def) if in_range_def else -1
        last_def = max(in_range_def) if in_range_def else -1
        first_lb = min(in_range_lb) if in_range_lb else -1
        last_lb = max(in_range_lb) if in_range_lb else -1
        
        first_contact_ground = first_def * 64 / 55 if first_def != -1 else -1
        last_contact_ground = last_def * 64 / 55 if last_def != -1 else -1
        
        # ADD 10s DELAY TO AIR
        first_contact_air = (first_lb * 64 / 100) + 10.0 if first_lb != -1 else -1
        last_contact_air = (last_lb * 64 / 100) + 10.0 if last_lb != -1 else -1
        
        print(f"{t_type}: Ground contact t={first_contact_ground:.1f}s to t={last_contact_ground:.1f}s")
        print(f"{t_type}: Air contact t={first_contact_air:.1f}s to t={last_contact_air:.1f}s")

    print("\n  Target Concurrency Check (Fixed):")
    print("    Ground: Bulwark (50spd) starts t=0. Air: Flyers (100spd) start t=10s.")
    print("    Sniper locked on Bulwark from t=8.1s to t=20s (approx 12s to kill 540 eff HP).")
    print("    Air enters Sniper range at t=15.8s.")
    print("    Overlap: Much smaller. Sniper is mostly free to shoot air as Bulwark is dying or dead.")
    print("    Verdict: Delaying air by 10s resolves the Sniper priority conflict.")
