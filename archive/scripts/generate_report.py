import json
import glob
import os

lessons = {
    1: {"lesson": "Basics of tower placement and straight paths.", "strategy": "Place basic towers near the path.", "risk": "Low"},
    2: {"lesson": "Corners and maximizing tower range.", "strategy": "Place towers at corners for max coverage.", "risk": "Low"},
    3: {"lesson": "Handling fast enemies with Rapid towers.", "strategy": "Use rapid towers near start.", "risk": "Low"},
    4: {"lesson": "Dealing with swarms using Cannon towers.", "strategy": "Cannon at choke points.", "risk": "Low"},
    5: {"lesson": "Combining towers to handle tanks and swarms.", "strategy": "Mix cannon and rapid/basic.", "risk": "Moderate"},
    6: {"lesson": "Split paths and prioritizing coverage.", "strategy": "Cover intersections.", "risk": "Moderate"},
    7: {"lesson": "Breaking through Shieldbearers.", "strategy": "Concentrate fire on shieldbearers.", "risk": "Moderate"},
    8: {"lesson": "Overcoming Healers with concentrated fire.", "strategy": "Burst damage with snipers.", "risk": "Moderate"},
    9: {"lesson": "Managing Splitters with splash damage.", "strategy": "Use cannons near end of paths.", "risk": "Moderate"},
    10: {"lesson": "Complex paths with full support enemies.", "strategy": "Balance single target and splash.", "risk": "Moderate"},
    11: {"lesson": "Hero deployment against Bulwarks.", "strategy": "Deploy hero to block bulwarks.", "risk": "High"},
    12: {"lesson": "Defending the Hero from Hunters.", "strategy": "Protect hero with snipers.", "risk": "High"},
    13: {"lesson": "Detecting and destroying Cloaked enemies.", "strategy": "Ensure overlapping fields of fire.", "risk": "High"},
    14: {"lesson": "Managing multiple threats with Hero abilities.", "strategy": "Use hero abilities on swarms.", "risk": "High"},
    15: {"lesson": "High pressure multi-lane ground assault.", "strategy": "Heavy use of slow and splash.", "risk": "High"},
    16: {"lesson": "Introduction to Air pressure (Flyers).", "strategy": "Build snipers and lightning.", "risk": "High"},
    17: {"lesson": "Fast flyers requiring Anti-Air tracking.", "strategy": "Lightning towers at corners.", "risk": "Extreme"},
    18: {"lesson": "Armored flyers requiring Sniper/Lightning.", "strategy": "Max level snipers on long lines.", "risk": "Extreme"},
    19: {"lesson": "Disruptors neutralizing towers.", "strategy": "Spread towers out to avoid EMP.", "risk": "Extreme"},
    20: {"lesson": "Final Exam: Multi-phase mixed assault.", "strategy": "Adapt to each wave phase. Reposition hero.", "risk": "Extreme"}
}

levels = sorted(glob.glob('data/levels/level_*.json'))

report = "# Level 1-20 Balance Pass Report\n\n"
report += "Generated based on the latest wave configurations and level metadata.\n\n"

report += "| Level | Lesson | Enemy Types | Recommended Roles | Gold | Rewards | Risk | Strategy |\n"
report += "|---|---|---|---|---|---|---|---|\n"

for lvl in levels:
    with open(lvl, 'r') as f:
        ldata = json.load(f)
    
    num = int(ldata['id'].split('_')[1])
    lesson_data = lessons.get(num, {})
    
    wpath = lvl.replace('levels', 'waves').replace('level_', 'waves_')
    total_rewards = 0
    enemy_types = set()
    if os.path.exists(wpath):
        with open(wpath, 'r') as f:
            wdata = json.load(f)
            for w in wdata:
                total_rewards += w.get('reward', 0)
                for g in w.get('groups', []):
                    enemy_types.add(g.get('type', ''))
                    
    types_str = ", ".join(sorted(enemy_types))
    roles_str = ", ".join(ldata.get('recommended_roles', []))
    
    row = f"| {ldata['id']} | {lesson_data.get('lesson')} | {types_str} | {roles_str} | {ldata.get('starting_gold')} | {total_rewards} | {lesson_data.get('risk')} | {lesson_data.get('strategy')} |"
    report += row + "\n"

with open("BALANCE_PASS_REPORT.md", "w") as f:
    f.write(report)
print("Report generated")
