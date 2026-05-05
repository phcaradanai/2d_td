# Clone Tower Defense

A polished, web-ready Tower Defense prototype built with Godot 4.6.2.

## Features
- 3 Playable levels with distinct paths and difficulties.
- 4 Unique towers (Basic, Rapid, Cannon, Slow).
- Progression system with level unlocking and high-score saving.
- Responsive HUD with audio settings and credits.
- Optimized for Web (itch.io, GitHub Pages).

## Version
**v0.1.0 Prototype**

## How to Play
- **Place Towers**: Select a tower from the left sidebar and click on a valid grid cell.
- **Select/Upgrade**: Click an existing tower to view stats and upgrade it.
- **Cancel**: Right-click or press `Esc` to cancel build mode or selection.
- **Start Wave**: Click the button in the top bar when ready.
- **Pause**: Press `Space` or the Pause button.

## Development
### Requirements
- Godot 4.6.2 (or compatible Godot 4.x)

### Running in Editor
1. Clone the repository.
2. Open `project.godot` in the Godot Editor.
3. Press `F5` to run.

### Web Export Instructions
1. Go to `Project -> Export`.
2. Select the **Web** preset.
3. Ensure the export path is a clean directory (e.g., `builds/web/`).
4. Set the filename to `index.html`.
5. Export Project.

### Local Web Testing
To test the web build locally, you must use a local server to handle the required headers:
```bash
python3 -m http.server 8080
```
Then visit `http://localhost:8080`.

**Note**: Browser audio will only start after your first click on the game.

## Asset Guidelines
### Tower Sprites
- **Default System**: The game uses **procedural drawing** (Godot vector art) by default for maximum clarity and web performance.
- **External Sprites (Optional)**: Can be enabled by setting `@export var use_external_sprite = true` in `Tower.gd`.
- **Format**: RGBA PNG (Transparent background).
- **Resolution**: 64x64 or 128x128 pixels (auto-scaled in-game).
- **Layers**: Supports single full tower OR split Base/Turret sprites.
  - **Single Sprite**: `[name]_tower_lv1.png`
  - **Split Sprites**: `[name]_tower_base_lv1.png` and `[name]_tower_turret_lv1.png`.
- **Direction**: Turrets should ideally point **Right (East)** or **Up (North)**.

## Credits
- **Developed by**: Antigravity AI
- **Engine**: Godot 4.6.2
- **Assets**: Open Source community assets.
# 2d_td
