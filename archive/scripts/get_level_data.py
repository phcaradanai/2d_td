import json
import glob

levels = sorted(glob.glob('data/levels/level_*.json'))

lessons = {
    1: "Basics of tower placement and straight paths.",
    2: "Corners and maximizing tower range.",
    3: "Handling fast enemies with Rapid towers.",
    4: "Dealing with swarms using Cannon towers.",
    5: "Combining towers to handle tanks and swarms.",
    6: "Split paths and prioritizing coverage.",
    7: "Breaking through Shieldbearers.",
    8: "Overcoming Healers with concentrated fire.",
    9: "Managing Splitters with splash damage.",
    10: "Complex paths with full support enemies.",
    11: "Hero deployment against Bulwarks.",
    12: "Defending the Hero from Hunters.",
    13: "Detecting and destroying Cloaked enemies.",
    14: "Managing multiple threats with Hero abilities.",
    15: "High pressure multi-lane ground assault.",
    16: "Introduction to Air pressure (Flyers).",
    17: "Fast flyers requiring Anti-Air tracking.",
    18: "Armored flyers requiring Sniper/Lightning.",
    19: "Disruptors neutralizing towers.",
    20: "Final Exam: Multi-phase mixed assault."
}

for lvl in levels:
    with open(lvl, 'r') as f:
        ldata = json.load(f)
    
    num = int(ldata['id'].split('_')[1])
    lesson = lessons.get(num, "Unknown")
    
    wpath = lvl.replace('levels', 'waves').replace('level_', 'waves_')
    total_enemies = 0
    total_rewards = 0
    enemy_types = set()
    if glob.glob(wpath):
        with open(wpath, 'r') as f:
            wdata = json.load(f)
            for w in wdata:
                total_rewards += w.get('reward', 0)
                for g in w.get('groups', []):
                    total_enemies += g.get('count', 0)
                    enemy_types.add(g.get('type', ''))
                    
    print(f"{ldata['id']}:")
    print(f"  lesson: {lesson}")
    print(f"  types: {', '.join(sorted(enemy_types))}")
    print(f"  gold: {ldata.get('starting_gold')} + {total_rewards} rewards")
