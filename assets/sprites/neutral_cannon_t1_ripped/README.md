# Neutral Cannon Tower T1 - Ripped Frames

Extracted from the uploaded sprite sheet.

Folders:
- `frames_fixed_256/` = transparent frames centered on fixed canvases, easiest for animation alignment.
- `frames_trimmed/` = tight transparent crops for packing/optimization.
- `spritesheet_all_fixed_256.png` = combined 256x256 transparent sheet for base/turret/fire/impact.
- `spritesheet_projectile_fixed_128.png` = projectile frame.
- `metadata.json` = frame names, source crop boxes, FPS suggestions.

Suggested animation settings:
- turret_rotation: 8 FPS, loop=true
- turret_fire: 12 FPS, loop=false
- splash_impact: 12 FPS, loop=false
- projectile: static
- tower_base: static

Godot note:
Use fixed frames if you want stable pivots. Suggested pivot/offset for 256x256 frames is center (128, 128).
