import json

towers = {
    "sniper": {"cost": 150, "range": 5.9, "dps": 25.0, "dmg": 55.0, "rate": 2.2, "aa": True, "priority": "high_hp"},
    "lightning": {"cost": 130, "range": 2.8, "dps": 18.75, "dmg": 15.0, "rate": 0.8, "aa": True, "chain": 3, "priority": "first"},
    "cannon": {"cost": 110, "range": 2.3, "dps": 12.8, "dmg": 18.0, "rate": 1.4, "aa": False, "aoe": True, "priority": "first"}
}
enemies = {
    "bulwark": {"hp": 450, "spd": 50, "cat": "land"},
    "shieldbearer": {"hp": 220, "spd": 55, "cat": "land"},
    "healer": {"hp": 180, "spd": 65, "cat": "land"},
    "tank": {"hp": 140, "spd": 55, "cat": "land"},
    "flyer": {"hp": 50, "spd": 100, "cat": "air"},
    "fast_flyer": {"hp": 35, "spd": 150, "cat": "air"}
}
# Placements (Variant A)
# Sniper at [9,4] -> sees ground 4.7s-20.9s, sees air 5.8s-11.5s
# Lightning at [9,8] -> sees ground 14.0s-16.3s, sees air 5.1s-9.0s
# Cannon at [10,5] -> sees ground 11.6s-18.6s, sees air 7.7s-10.2s

spawns = [
    {"type": "bulwark", "t": 0.0},
    {"type": "shieldbearer", "t": 1.0},
    {"type": "healer", "t": 2.5},
    {"type": "tank", "t": 4.0},
    {"type": "tank", "t": 5.5},
    {"type": "flyer", "t": 7.0},
    {"type": "flyer", "t": 8.3},
    {"type": "flyer", "t": 9.6},
    {"type": "fast_flyer", "t": 10.9}
]

print("--- NEW TIMING PYTHON SIM ---")
for s in spawns:
    e = enemies[s["type"]]
    reach_choke = s["t"] + (11 * 64 / e["spd"]) # rough estimate to mid map
    base = s["t"] + (24 * 64 / e["spd"])
    print(f"{s['type']:15} spawns t={s['t']:4.1f}s | reaches choke t={reach_choke:4.1f}s | base t={base:4.1f}s")

print("\nSniper is locked on Bulwark from t=4.7s to t=20.9s")
print("Fast_flyer spawns at t=10.9s, reaches choke at t=15.5s, reaches base at t=21.1s")
print("Lightning sees fast_flyer from t=16.0s to 19.9s (approx)")
print("Lightning DPS = 18.75. Fast_flyer HP = 35. Time to kill = 1.9s.")
print("Wait, if Lightning is alone against fast_flyer, it CAN kill it!")
print("But Lightning is ALSO fighting flyers from t=12.1s to 16.0s.")
print("Flyer 3 spawns at 9.6s, reaches base at 24.9s.")
print("The fast flyer actually overtakes Flyer 3 at t=20.5s!")
