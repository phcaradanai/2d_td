# Clone Tower Defense

A high-fidelity, industrial sci-fi Tower Defense experience built with **Godot 4.6.2**. This prototype features modular procedural visuals, advanced wave previews, and a campaign progression system.

## Release Candidate (v1.0.0-RC1)
- **Levels**: 20 Playable missions across 4 distinct thematic areas (Grasslands, Forest, River, Mountain).
- **Towers**: 7 Unique tower types (Basic, Rapid, Cannon, Slow, Sniper, Lightning, Sawblade).
- **Environment**: High-fidelity modular sci-fi facility aesthetic with neon energy paths.
- **Hero System**: Guardian deployment available starting from Level 11.
- **Map Mechanics**: "Restricted Foundations" mechanics introduced from Level 12 for tactical variety.
- **Progression**: Full campaign progression, star ratings, and local save persistence.
- **Platform**: Production-ready Web (WASM/WebGL) and Desktop exports.

## Features
- **Wave Preview UI**: Authorization-style holographic energy walls and triple-chevron flow indicators.
- **Procedural Graphics**: All towers and environments use high-performance vector-style drawing for maximum clarity.
- **Area Themes**: Distinct color palettes and decorative layers (Vents, Cables, Circuitry) for different facility sectors.
- **Release Hygiene**: Gated debug/dev tools and optimized console logging for a clean production experience.

- **Build**: Select a tower from the sidebar and click on a valid cell (cyan highlight).
- **Hero (Level 11+)**: Click the Guardian icon or press `H` to deploy.
- **Upgrade**: Click an existing tower to view stats and upgrade levels.
- **Cancel**: Right-click or press `Esc` to exit build mode.
- **Pause**: Press `Space` or the Pause button.
- **Debug Tools**: Internal only (`F1` for menu, `F9/F10` for auto-solve).

## Development Status

### [x] Implemented
- Complete 20-level campaign with increasing difficulty.
- Modular Map Visual Layer with procedural sci-fi geometry.
- Hero Guardian logic and manual tactical deployment.
- "Restricted Foundations" build mode for advanced mission design.
- Web-optimized audio manager with unlock-on-gesture logic.
- Production-safe Star rating and score persistence.
- Gated internal debug tools and automated health-check scripts.

### [/] In Progress
- Additional Enemy Type varieties (refined Air logic).
- Enhanced Tactical Wave Intel (real-time composition tooltips).
- Global Leaderboard service integration.

## Technical Setup
- **Engine**: Godot 4.6.2 (Stable).
- **Running in Editor**: Open `project.godot` and press `F5`.
- **Web Testing**: Use a local server to handle SharedArrayBuffer headers:
  ```bash
  python3 -m http.server 8080
  ```
  Then visit `http://localhost:8080`.

## Credits
- **Developed by**: Antigravity AI
- **Assets**: Procedural generation and curated open-source sound effects.