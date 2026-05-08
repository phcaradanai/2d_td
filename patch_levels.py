import json
import glob

lessons = {
    1: {"lesson": "Basics of tower placement and straight paths.", "roles": ["Basic", "Rapid"], "intel": ["Basic Nodes"]},
    2: {"lesson": "Corners and maximizing tower range.", "roles": ["Basic", "Rapid"], "intel": ["Basic Nodes"]},
    3: {"lesson": "Handling fast enemies with Rapid towers.", "roles": ["Rapid", "Basic", "Slow"], "intel": ["Signal Runner"]},
    4: {"lesson": "Dealing with swarms using Cannon towers.", "roles": ["Cannon", "Rapid", "Basic"], "intel": ["Data Swarm"]},
    5: {"lesson": "Combining towers to handle tanks and swarms.", "roles": ["Cannon", "Sniper", "Basic"], "intel": ["Heavy Shell"]},
    6: {"lesson": "Split paths and prioritizing coverage.", "roles": ["Cannon", "Rapid", "Basic"], "intel": ["Shieldbearer"]},
    7: {"lesson": "Breaking through Shieldbearers.", "roles": ["Cannon", "Lightning", "Slow"], "intel": ["Shieldbearer"]},
    8: {"lesson": "Overcoming Healers with concentrated fire.", "roles": ["Sniper", "Basic", "Lightning"], "intel": ["Repair Drone"]},
    9: {"lesson": "Managing Splitters with splash damage.", "roles": ["Cannon", "Lightning", "Rapid"], "intel": ["Fragmenter"]},
    10: {"lesson": "Complex paths with full support enemies.", "roles": ["Cannon", "Sniper", "Slow"], "intel": ["Support Mix"]},
    11: {"lesson": "Hero deployment against Bulwarks.", "roles": ["Cannon", "Lightning", "Slow"], "intel": ["Bulwark Alpha", "Viral Predator"]},
    12: {"lesson": "Defending the Hero from Hunters.", "roles": ["Sniper", "Basic", "Lightning"], "intel": ["Viral Predator"]},
    13: {"lesson": "Detecting and destroying Cloaked enemies.", "roles": ["Rapid", "Lightning"], "intel": ["Ghost Code"]},
    14: {"lesson": "Managing multiple threats with Hero abilities.", "roles": ["Sniper", "Cannon", "Lightning"], "intel": ["Heavy Mix"]},
    15: {"lesson": "High pressure multi-lane ground assault.", "roles": ["Cannon", "Lightning", "Slow", "Sawblade"], "intel": ["Ground Assault"]},
    16: {"lesson": "Introduction to Air pressure (Flyers).", "roles": ["Sniper", "Lightning", "Rapid"], "intel": ["Cyber Drone"]},
    17: {"lesson": "Fast flyers requiring Anti-Air tracking.", "roles": ["Sniper", "Lightning"], "intel": ["Interceptor"]},
    18: {"lesson": "Armored flyers requiring Sniper/Lightning.", "roles": ["Sniper", "Lightning", "Slow"], "intel": ["Heavy Drone"]},
    19: {"lesson": "Disruptors neutralizing towers.", "roles": ["Sniper", "Lightning", "Rapid"], "intel": ["EMP Wasp"]},
    20: {"lesson": "Final Exam: Multi-phase mixed assault.", "roles": ["Sniper", "Lightning", "Rapid", "Cannon", "Slow", "Sawblade"], "intel": ["All Types"]}
}

levels = sorted(glob.glob('data/levels/level_*.json'))

for lvl in levels:
    with open(lvl, 'r') as f:
        data = json.load(f)
    
    num = int(data['id'].split('_')[1])
    lesson_data = lessons.get(num, {"roles": [], "intel": []})
    
    data['recommended_roles'] = lesson_data['roles']
    data['enemy_intel'] = lesson_data['intel']
    
    with open(lvl, 'w') as f:
        json.dump(data, f, indent=4)
        
print("Updated levels")
