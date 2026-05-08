import json
import os
import glob

levels = sorted(glob.glob('data/levels/level_*.json'))

for level_path in levels:
    with open(level_path, 'r') as f:
        ldata = json.load(f)
    
    wpath = 'data/waves/' + os.path.basename(level_path).replace('level_', 'waves_')
    if os.path.exists(wpath):
        with open(wpath, 'r') as f:
            wdata = json.load(f)
            
        total_enemies = 0
        enemy_types = set()
        for w in wdata:
            for g in w.get('groups', []):
                total_enemies += g.get('count', 0)
                enemy_types.add(g.get('type', ''))
                
        print(f"{ldata['id']}: gold={ldata.get('starting_gold')}, waves={len(wdata)}, total_enemies={total_enemies}, types={','.join(enemy_types)}")
